#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

# Github Issue Labels
# Script to copy issue labels from one repository to another
# Copyright © 2017  Basil Peace
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# 	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'octokit'
require 'thor'
require 'logger'
require 'paint'
require 'color'

Octokit.auto_paginate = true

GITHUB_DEFAULT_ISSUE_LABELS = [
  'bug',
  'duplicate',
  'enhancement',
  'help wanted',
  'invalid',
  'question',
  'wontfix'
].freeze

# CLI
class GithubIssueLabels < Thor
  desc 'copy organization source target', 'Copy issue labels from source to target repositories'
  option :remove_defaults, type: :boolean, default: false, desc: 'Remove default Github issue labels [by default do not]'

  def initialize(args = [], local_options = {}, config = {})
    super
    @logger = Logger.new(STDOUT)
    @client = Octokit::Client.new(access_token: ENV['GH_TOKEN'])
  end

  def copy(organization, source, target)
    remove_defaults = options[:remove_defaults]
    if target == '*'
      @client.organization_repositories(organization).each do |repository|
        copy organization, source, repository.name unless repository.name == source
      end
    else
      source = "#{organization}/#{source}"
      target = "#{organization}/#{target}"
      if source == target
        @logger.info "Skipping #{source}"
        return
      end
      @logger.info "Updating #{target}"
      if remove_defaults
        GITHUB_DEFAULT_ISSUE_LABELS.each do |label_name|
          next if get_label(source, label_name)
          current_label = get_label(target, label_name)
          if current_label
            if @client.delete_label! target, label_name
              @logger.info "#{target}: #{get_colorized_label(current_label)} deleted"
            else
              @logger.error "#{target}: #{get_colorized_label(current_label)} was not deleted by error"
            end
          end
        end
      end
      @client.labels(source).each do |label|
        colorized_label = get_colorized_label(label)
        current_label = get_label(target, label.name)
        if current_label
          if current_label.name != label.name || current_label.color != label.color
            @client.update_label target, label.name, name: label.name, color: label.color
            @logger.info "#{target}: #{get_colorized_label(current_label)} updated to #{colorized_label}"
          else
            @logger.info "#{target}: #{colorized_label} was not changed"
          end
        else
          @client.add_label target, label.name, label.color
          @logger.info "#{target}: #{colorized_label} added"
        end
      end
    end
  end

  def self.exit_on_failure?
    true
  end

  protected

  def get_label(repository, label_name)
    @client.label repository, label_name
  rescue Octokit::NotFound
    return nil
  end

  def get_colorized_label(label)
    Paint[label.name, ::Color::RGB.from_html(label.color).to_yiq.brightness > (186.0 / 255) ? 'black' : 'white', label.color, :bold]
  end
end

GithubIssueLabels.start(ARGV) if $PROGRAM_NAME == __FILE__
