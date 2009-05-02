#!/usr/bin/ruby

SCRIPT_ROOT=File.dirname(__FILE__)
$:.unshift File.join(SCRIPT_ROOT, '..', 'lib')

require 'mail_notifier.rb'
require 'yaml'


if $0 == __FILE__ then
	store_path = ENV['HOME'] + '/.mailnotifier'
	asset_path = File.join(SCRIPT_ROOT, '../assets')
	config_path = "#{store_path}/config.yml"

	mailboxes = []
	if (File.exists?(config_path))
		mailboxes = File.open(config_path) { |f| YAML::load( f ) }
	end
	
	if (mailboxes.size > 0)
		#continue
	else
		puts "Invalid or Missing config file: #{config_path}"
		exit!
	end

	
	mail_notifier = MailNotifier.new({
		:asset_dir => asset_path,
		:store_dir => store_path,
		:mailboxes => mailboxes,
		:debug => 1
	})
	mail_notifier.check_mailboxes
	# Although it has no UI, this has to be an OS X application because
	# the run loop is needed to handle Growl callbacks.
	NSApplication.sharedApplication
	NSApp.run
end

