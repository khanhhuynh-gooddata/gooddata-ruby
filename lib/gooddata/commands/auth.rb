# encoding: UTF-8
#
# Copyright (c) 2010-2017 GoodData Corporation. All rights reserved.
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

require 'highline/import'

require_relative '../cli/terminal'
require_relative '../helpers/helpers'

module GoodData
  module Command
    class Auth
      class << self
        # Ask for credentials
        # @param [String] credentials_file_path (credentials_file) Path to .gooddata file
        # @return [Hash]
        #   * :username [String] Username (email address)
        #   * :password [String] Password
        #   * :auth_token [String] Authorization token
        #   * :environment [String] Environment - DEVELOPMENT, TEST, PRODUCTION
        #   * :server => [String] Server - https://secure.gooddata.com
        def ask_for_credentials(credentials_file_path = Helpers::AuthHelper.credentials_file)
          puts 'Enter your GoodData credentials.'

          old_credentials = Helpers::AuthHelper.read_credentials(credentials_file_path)

          # Ask for user email
          user = GoodData::CLI.terminal.ask('Email') do |q|
            set_default_value(q, old_credentials[:username])
          end

          # Ask for password
          password = GoodData::CLI.terminal.ask('Password') do |q|
            # set_default_value(q, old_credentials[:password])
            q.echo = '*'
          end

          # Ask for token
          auth_token = GoodData::CLI.terminal.ask('Authorization (Project) Token') do |q|
            set_default_value(q, old_credentials[:auth_token])
          end

          # Read environment
          environment = GoodData::CLI.terminal.ask('Environment') do |q|
            set_default_value(q, old_credentials[:environment], GoodData::Project::DEFAULT_ENVIRONMENT)
          end

          # Read server
          server = GoodData::CLI.terminal.ask('Server') do |q|
            set_default_value(q, old_credentials[:server], 'https://secure.gooddata.com')
          end

          # Return as struct
          {
            :username => user,
            :password => password,
            :auth_token => auth_token,
            :environment => environment,
            :server => server
          }
        end

        def ask_for_credentials_on_windows(credentials_file_path = Helpers::AuthHelper.credentials_file)
          puts 'Enter your GoodData credentials.'

          old_credentials = Helpers::AuthHelper.read_credentials(credentials_file_path)

          puts 'Email'
          input = $stdin.gets.chomp
          user = input.empty? ? old_credentials[:username] : input

          puts 'Password'
          input = $stdin.gets.chomp
          password = input.empty? ? old_credentials[:password] : input

          puts 'Authorization (Project) Token'
          input = $stdin.gets.chomp
          auth_token = input.empty? ? old_credentials[:auth_token] : input

          puts 'Environment'
          input = $stdin.gets.chomp
          environment = input.empty? ? old_credentials[:environment] : input
          # in windows console, an empty input does not flush the previous buffer
          # so if you do not fill any environment, the previous value is still present in $stdin
          # so this is a default
          environment = GoodData::Project::DEFAULT_ENVIRONMENT if environment == auth_token

          puts 'Server'
          input = $stdin.gets.chomp
          server = input.empty? ? old_credentials[:server] : input

          # Return as struct
          {
            :username => user,
            :password => password,
            :auth_token => auth_token,
            :environment => environment,
            :server => server
          }
        end

        # Ask for credentials and store them
        def store(credentials_file_path = Helpers::AuthHelper.credentials_file)
          puts 'This will store credentials to GoodData in an UNencrypted form to your harddrive to file ~/.gooddata.'
          overwrite = GoodData::CLI.terminal.ask('Do you want to continue? (y/n)')
          return if overwrite != 'y'

          credentials = GoodData::Helpers.running_on_windows? ? ask_for_credentials_on_windows : ask_for_credentials

          ovewrite = if File.exist?(credentials_file_path)
                       GoodData::CLI.terminal.ask('Overwrite existing stored credentials (y/n)')
                     else
                       'y'
                     end

          if ovewrite == 'y'
            Helpers::AuthHelper.write_credentials(credentials, credentials_file_path)
          else
            puts 'Aborting...'
          end
        end

        # Delete stored credentials
        def unstore(credentials_file_path = Helpers::AuthHelper.credentials_file)
          Helpers::AuthHelper.remove_credentials_file(credentials_file_path)
        end

        # Conditionally sets default value for prompt.
        # Default value is set to 'value' or 'default'
        #
        # @param [Highline] q Highline instance used
        # @param [String] value Value used for ask default if not nil and not empty
        # @param [String] default Value used for ask default iv 'value' is nil or empty
        def set_default_value(q, value, default = nil)
          if !value.nil? && !value.empty?
            q.default = value
          elsif default
            q.default = default
          end
        end
      end
    end
  end
end
