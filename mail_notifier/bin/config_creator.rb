#!/usr/bin/ruby

require 'yaml'
require 'net/pop'

SCRIPT_ROOT=File.dirname(__FILE__)
$:.unshift File.join(SCRIPT_ROOT, '..', 'lib')


if (!ARGV[0])
	puts "Please specify an output file (config.yml)"
	exit!
end


output_file = ARGV[0]

def test_connection(pserver,puser,ppass,ssl=false)
	puts "\nTesting connection...(may take up to 30 seconds)"
	pop = Net::POP3.new(pserver)
	if (ssl) 
		pop.enable_ssl()
	end
	pop.read_timeout = 10
	
	begin
		pop.start(puser,ppass)
	rescue Exception => e
		pop.finish if pop.started?
		puts "Connection Failed (#{e})!\n"
		return nil
	end

	if pop.active?
		pop.finish
		puts "Successfully Connected!\n"
		return 1
	end
	
	pop.finish if pop.started?
	puts "Connection Failed!\n"
	return nil
end

def get_named_param(label)
	print "Enter your #{label}: "
	answ = STDIN.gets.chomp
	return answ if (answ != "")
	return get_named_param(label)
end

def get_mailbox_data
	name = get_named_param("Mailbox Name")
	link = get_named_param("Mailbox Link")
	server = get_named_param("Mailbox Server")
	uname = get_named_param("Mailbox Username")
	pass = get_named_param("Mailbox Password")
	ssl = false
	if (!test_connection(server,uname,pass))
		if (test_connection(server,uname,pass,true))
			ssl = true
		else
			return nil
		end
	end
	return {
		:name => name,
		:link => link,
		:server => server,
		:user => uname,
		:pass => pass,
		:ssl => ssl
	}
end

def should_continue(str)
	print "#{str} (Y/n) "
	continue_question = STDIN.gets.chomp
	
	return nil if (continue_question == 'n')
	return 1 if (continue_question == 'Y')
	return should_continue
end


getting_input = 1
mailboxes = []

while (getting_input)
	mailbox = get_mailbox_data
	if (mailbox)
		mailboxes.push mailbox
	else
		puts "--Connection FAILED!--"
	end

	if (!should_continue("Would you like to add another mailbox?"))
		getting_input = nil
		puts "-----"
	end
end


File.open(output_file, 'w') { |f| f.puts mailboxes.to_yaml }

puts "Wrote yaml config to: #{output_file}"

if (should_continue("Would you like to copy the config to ~/.mailnotifier/config.yml?"))
	File.open("#{ENV['HOME']}/.mailnotifier/config.yml", 'w') { |f| f.puts mailboxes.to_yaml }
end

puts "Copy the generated file to ~/.mailnotifier/config.yml to implement the changes"
puts "-----"
