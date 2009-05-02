#!/usr/bin/ruby

require 'rubygems'
require 'osx/cocoa'
require 'net/pop'
require 'sqlite3'
require 'ftools'
include OSX
require 'growl'



class MailNotifier
	
	MESSAGE_SHOW_LIMIT = 5

	APP_NAME = 'RubyMailNotifier'
	# The different kinds of messages you might send to Growl.
	RESPONSIVE_KIND = 'message_count'
	UNRESPONSIVE_KIND = 'message_info'
	DEFAULT_NOTIFICATION = RESPONSIVE_KIND
	
	
	
	APP_ICON = 'MailboxIcon.png'
	MESSAGE_ICON = 'MailNotifierIcon.png'
	LOG_FILE = 'rubymail_test.log'
	SQLITE_FILE = 'rubymail_notifier3.db'

	

	@debug_mode = 0
	def set_debug(n)
		@debug_mode = n
	end	
	
	@debug_handle = 0	
	
	
	# Tell the Growl Notifier class that we’ll be handling
	# callbacks from Growl.
	def initialize(args)
		@db = 0
		
		@open_mailboxes = {}
		@checking_mailboxes = nil

		@mailboxes = args[:mailboxes]
		@asset_dir = args[:asset_dir]	
		@store_dir = args[:store_dir]


		if (!File::exists?( @store_dir ) )
			File::makedirs( @store_dir )
		end
		
		#store directory must exist for this to work
		set_debug(1) if args[:debug]


		@app_icon = NSImage.alloc.initWithContentsOfFile("#{@asset_dir}/#{APP_ICON}")
		@message_icon = NSImage.alloc.initWithContentsOfFile("#{@asset_dir}/#{MESSAGE_ICON}")

		@log_file = "#{@store_dir}/#{LOG_FILE}"
		@sqlite_file = "#{@store_dir}/#{SQLITE_FILE}"


		@growl = Growl::Notifier.alloc.initWithDelegate(self)
		@growl.start(
			APP_NAME, 
			[ RESPONSIVE_KIND, UNRESPONSIVE_KIND ],
			[ DEFAULT_NOTIFICATION ],
			@app_icon)
		
		init_db
		
		debug("Asset path is #{@asset_dir}");
	end

	def init_db
		
		if File::exists?( @sqlite_file )
			@db = SQLite3::Database.new(@sqlite_file)
		else

			@db = SQLite3::Database.new(@sqlite_file)
			@db.execute("create table messages (
				mailbox_name VARCHAR(255),
				message_count INTEGER(11),
				cr_date DATETIME
			)")
			@db.execute("create table errors (
				mailbox_name VARCHAR(255),
				error_text TEXT,
				cr_date DATETIME
			)")

		end
	end


	def close_db
		@db.close
	end



	# The "context" argument 
	# tells Growl that we want a callback.
	def new_messages_notification(mailbox_name,mailbox_link,new_message_count,total_message_count)
		message_multiple = new_message_count > 1 ? 'msgs' : 'msg'
		message_desc = new_message_count > 1 ? 'Click here to read them.' : 'Click here to read it.'

		@growl.notify(
			kind = RESPONSIVE_KIND,
			title = "#{new_message_count} new #{message_multiple} | #{mailbox_name} (#{total_message_count})",
			description = message_desc,
			context = mailbox_name, 
			sticky = true, 
			priority = 0
		)
	end

	def truncate_words(text, length = 20, end_string = '...')
	    words = text.split()
		words[0..(length-1)].join(' ') + (words.length > length ? end_string : '')
	end

	def message_notification(message_info)		
		@growl.notify(
			kind = RESPONSIVE_KIND,
			title = String(message_info['from']).chomp(),
			description = "[ #{truncate_words(message_info['subject'],5)} ]\n#{truncate_words( String(message_info['body']).chomp() )}",
			context = nil, 
			sticky = false, 
			priority = 0,
			icon = @message_icon
		)
	end

	def throw_error(context,error)
		@db.execute( "insert into errors (cr_date,mailbox_name,error_text) VALUES (datetime('now'),'#{context}','#{error}')" ) 
		exit_smoothly(context)
	end

	def growl_onTimeout(sender, context)
		exit_smoothly(context)
	end

	# This is the callback method for clicks.
	def growl_onClicked(sender, context)
		debug('hello')
		dom = ''
		#get link from context
		@mailboxes.each do |mbox|
			if (mbox[:name] == context.to_s)
				dom = mbox[:link]
			end
		end
		debug("Found Link: #{dom} from context: #{context}")
		
		@res = `open #{dom}`
		exit_smoothly(context)
	end
		
	
	def debug(str)
		if @debug_mode
			if !@debug_handle
				start_debug()
			end
			@debug_handle.write str
			@debug_handle.write "\n"
		end
	end


	def start_debug()
		@debug_handle = File.open(@log_file,'w')
	end

	def end_debug()
		if @debug_handle
			@debug_handle.close
		end
	end

	def exit_smoothly(context=nil)
		if (context)
			@open_mailboxes.delete_if {|key,value| key == context}
			debug("In Exit for mailbox: #{context}")
		end
		i = 0
		@open_mailboxes.each do |key,value| 
			i += 1
		end
		return if (i > 0 || @checking_mailboxes)
		debug("Exiting Program from context: #{context}")
		end_debug()	
		exit!
	end

	def check_mailboxes
		@checking_mailboxes = 1
		@mailboxes.each { |mbox| 
			#sleep(8) if (@checking_mailboxes > 1)
			check_mailbox(mbox)
			@checking_mailboxes += 1
		}
		@checking_mailboxes = nil
		debug("Done check all mailboxes")
		exit_smoothly
	end


	def check_mailbox(mbox)

		debug("Checking Mailbox #{mbox[:name]}")

		have_mails = get_mailbox(mbox[:name],mbox[:server],mbox[:user],mbox[:pass])
		
		mail_count = have_mails['new_count']
		i = mail_count - 1
		
		if (mail_count > 0) 
			debug("Found #{mail_count} new messages")
		
			#display a clickable notification
			new_messages_notification(mbox[:name],mbox[:link],mail_count,have_mails['total_count'])	
			max_check = 0
			while (i >=0 && max_check < MESSAGE_SHOW_LIMIT)
				current_message = have_mails['new_messages'][i]
				important_info = parse_email(current_message)
				message_notification(important_info)
				i -= 1
				max_check += 1
			end

			@open_mailboxes[mbox[:name]] = 1

		else
			debug("Found no new messages")
			exit_smoothly(mbox[:name])
		end
		
	end

	def parse_email(email_str)
		subject = 'email subject'
		body = 'email body'
		from = 'jeffer@lanza.com'
	

		email_str =~ /^Subject: (.*)$/
		subject = $1.to_s
		email_str =~ /^From: (.*)$/
		from = $1.to_s
	
		body = ''
		reached_body = 0
		str = String.new(email_str)
		str.each_line() {|s|	
			if (reached_body > 0) 
				body = "#{body}#{s}"
			end
			if (String.new(s).chomp.match(/^$/im)) 
				reached_body = 1
			end
		}

		return {
			'subject' => subject,
			'body' => body,
			'from' => from
		}
	end


	def get_last_mail_count(mailbox_name)
		new_mail_count = -1
		@db.execute( "select message_count from messages where cr_date > datetime('now','-1 day') AND mailbox_name = '#{mailbox_name}' order by cr_date DESC LIMIT 1" ) do |row|
			found_count = row[0].to_i	
			if ( found_count >= 0) 
				new_mail_count = found_count
			end
		end

		if (new_mail_count < 0)
			#INIT IF FIRST CHECK
			@db.execute( "select count(*) from messages where mailbox_name = '#{mailbox_name}'" ) do |row|
				found_count = row[0].to_i
				debug("found_count is #{found_count}")
				if (found_count == 0) 
					new_mail_count = 0
				end
			end
		end

		if (new_mail_count < 0)
			throw_error(mailbox_name,"Last mail count was invalid!")
		end

		debug("get mail count for #{mailbox_name}: it is #{new_mail_count}")
		return new_mail_count
	end
	
	def set_new_mail_count(mailbox_name,num_messages)
		@db.execute( "insert into messages (cr_date,mailbox_name,message_count) VALUES (datetime('now'),'#{mailbox_name}',#{num_messages})" ) 
		debug("Set new mail count for #{mailbox_name} to #{num_messages}")
	end

	def get_mailbox(mailbox_name,pserver,puser,ppass)
		last_mail_count = get_last_mail_count(mailbox_name)
		debug("last_mail_count #{last_mail_count}")
		return_count = 0
		new_messages = []
		new_mail_count = -1
		pop = Net::POP3.start(pserver,110,puser,ppass)
		if pop.mails.empty?
			return_count = 0
		else
			new_mail_count = pop.n_mails
			if (new_mail_count >= last_mail_count)
				return_count = new_mail_count - last_mail_count
				set_new_mail_count(mailbox_name,new_mail_count)
				i = 0
				pop.each_mail do |m|   # or "pop.mails.each ..."   # (2)
					if (i >= last_mail_count) 
						debug("Get Message #{i}")
						new_messages.push m.pop
					end
					i += 1
				end
				
			else
				return_count = -1
			end
		end
		pop.finish
		
		return { 
			'new_count' => return_count,
			'new_messages' => new_messages,
			'total_count' => new_mail_count
		}
	end



end


