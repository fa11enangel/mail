# encoding: utf-8
require File.join(File.dirname(File.expand_path(__FILE__)), '..', 'spec_helper')

describe Mail::Message do
  
  def basic_email
    "To: mikel\r\nFrom: bob\r\nSubject: Hello!\r\n\r\nemail message\r\n"
  end
  
  describe "initialization" do
  
    it "should instantiate empty" do
      Mail::Message.new.class.should == Mail::Message
    end
  
    it "should instantiate with a string" do
      Mail::Message.new(basic_email).class.should == Mail::Message
    end
  
    it "should allow us to pass it a block" do
      mail = Mail::Message.new do
        from 'mikel@me.com'
        to 'lindsaar@you.com'
      end
      mail.from.should == ['mikel@me.com']
      mail.to.should == ['lindsaar@you.com']
    end
  
    it "should initialize a body and header class even if called with nothing to begin with" do
      mail = Mail::Message.new
      mail.header.class.should == Mail::Header
      mail.body.class.should == Mail::Body
    end
  
    it "should be able to parse a basic email" do
      doing { Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'basic_email.eml'))) }.should_not raise_error
    end

    it "should be able to parse an email with only blank lines as body" do
      doing { Mail::Message.new(File.read(fixture('emails', 'error_emails', 'missing_body.eml'))) }.should_not raise_error
    end

    it "should be able to parse every email example we have without raising an exception" do
      emails = Dir.glob( fixture('emails/**/*') ).delete_if { |f| File.directory?(f) }
      STDERR.stub!(:puts) # Don't want to get noisy about any warnings
      emails.each do |email|
        Mail::Message.new(File.read(email))
      end
    end

    it "should raise a warning (and keep parsing) on having non US-ASCII characters in the header" do
      STDERR.should_receive(:puts)
      Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'raw_email_string_in_date_field.eml')))
    end

    it "should raise a warning (and keep parsing) on having an incorrectly formatted header" do
      STDERR.should_receive(:puts).with("WARNING: Could not parse (and so ignorning) 'quite Delivered-To: xxx@xxx.xxx'")
      Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'raw_email_incorrect_header.eml')))
    end

    it "should read in an email message and basically parse it" do
      mail = Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'basic_email.eml')))
      mail.to.should == ["raasdnil@gmail.com"]
    end
    
  end
  
  describe "envelope line handling" do
    it "should respond to 'envelope from'" do
      Mail::Message.new.should respond_to(:envelope_from)
    end
    
    it "should strip off the envelope from field if present" do
      message = Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'raw_email.eml')))
      message.envelope_from.should == "jamis_buck@byu.edu"
      message.envelope_date.should == ::DateTime.parse("Mon May  2 16:07:05 2005")
    end
    
    it "should strip off the envelope from field if present" do
      message = Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'raw_email.eml')))
      message.raw_envelope.should == "jamis_buck@byu.edu Mon May  2 16:07:05 2005"
      message.from.should == ["jamis@37signals.com"]
    end

    it "should not cause any problems if there is no envelope from present" do
      message = Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'basic_email.eml')))
      message.from.should == ["test@lindsaar.net"]
    end

  end
  
  describe "accepting a plain text string email" do

    it "should accept some email text to parse and return an email" do
      mail = Mail::Message.new(basic_email)
      mail.class.should == Mail::Message
    end

    it "should set a raw source instance variable to equal the passed in message" do
      mail = Mail::Message.new(basic_email)
      mail.raw_source.should == basic_email.strip
    end

    it "should set the raw source instance variable to '' if no message is passed in" do
      mail = Mail::Message.new
      mail.raw_source.should == ""
    end
  
    it "should give the header class the header to parse" do
      header = Mail::Header.new("To: mikel\r\nFrom: bob\r\nSubject: Hello!")
      Mail::Header.should_receive(:new).with("To: mikel\r\nFrom: bob\r\nSubject: Hello!").and_return(header)
      mail = Mail::Message.new(basic_email)
    end

    it "should give the header class the header to parse even if there is no body" do
      header = Mail::Header.new("To: mikel\r\nFrom: bob\r\nSubject: Hello!")
      Mail::Header.should_receive(:new).with("To: mikel\r\nFrom: bob\r\nSubject: Hello!").and_return(header)
      mail = Mail::Message.new("To: mikel\r\nFrom: bob\r\nSubject: Hello!")
    end
  
    it "should give the body class the body to parse" do
      body = Mail::Body.new("email message")
      Mail::Body.should_receive(:new).with("email message").and_return(body)
      mail = Mail::Message.new(basic_email)
    end
  
    it "should still ask the body for a new instance even though these is nothing to parse, yet" do
      Mail::Body.should_receive(:new)
      mail = Mail::Message.new("To: mikel\r\nFrom: bob\r\nSubject: Hello!")
    end

    it "should give the header the part before the line without spaces and the body the part without" do
      header = Mail::Header.new("To: mikel")
      body = Mail::Body.new("G'Day!")
      Mail::Header.should_receive(:new).with("To: mikel").and_return(header)
      Mail::Body.should_receive(:new).with("G'Day!").and_return(body)
      mail = Mail::Message.new("To: mikel\r\n\r\nG'Day!")
    end
  
    it "should give allow for whitespace on the gap line between header and body" do
      header = Mail::Header.new("To: mikel")
      body = Mail::Body.new("G'Day!")
      Mail::Header.should_receive(:new).with("To: mikel").and_return(header)
      Mail::Body.should_receive(:new).with("G'Day!").and_return(body)
      mail = Mail::Message.new("To: mikel\r\n   		  \r\nG'Day!")
    end

    it "should allow for whitespace at the start of the email" do
      mail = Mail.new("\r\n\r\nFrom: mikel\r\n\r\nThis is the body")
      mail.from.should == ['mikel']
      mail.body.to_s.should == 'This is the body'
    end
    
    it "should read in an email message with the word 'From' in it multiple times and parse it" do
      mail = Mail::Message.new(File.read(fixture('emails', 'mime_emails', 'two_from_in_message.eml')))
      mail.to.should_not be_nil
      mail.to.should == ["tester2@test.com"]
    end    

  end
  
  describe "directly setting values of a message" do

    describe "accessing fields directly" do
      
      before(:each) do
        @mail = Mail::Message.new
      end

      it "should allow you to grab field objects if you really want to" do
        @mail.header_fields.class.should == Mail::FieldList
      end
      
      it "should give you back the fields in the header" do
        @mail['bar'] = 'abcd'
        @mail.header_fields.length.should == 1
        @mail['foo'] = '4321'
        @mail.header_fields.length.should == 2
      end
      
      it "should delete a field if it is set to nil" do
        @mail['foo'] = '4321'
        @mail.header_fields.length.should == 1
        @mail['foo'] = nil
        @mail.header_fields.length.should == 0
      end
      
      
      
    end

    describe "with :method=" do

      before(:each) do
        @mail = Mail::Message.new
      end

      it "should return the to field" do
        @mail.to = "mikel"
        @mail.to.should == ["mikel"]
      end

      it "should return the from field" do
        @mail.from = "bob"
        @mail.from.should == ["bob"]
      end

      it "should return the subject" do
        @mail.subject = "Hello!"
        @mail.subject.should == "Hello!"
      end

      it "should return the body decoded with to_s" do
        @mail.body "email message\r\n"
        @mail.body.to_s.should == "email message\n"
      end

      it "should return the body encoded if asked for" do
        @mail.body "email message\r\n"
        @mail.body.encoded.should == "email message\r\n"
      end

      it "should return the body decoded if asked for" do
        @mail.body "email message\r\n"
        @mail.body.decoded.should == "email message\n"
      end
    end
    
    describe "with :method(value)" do

      before(:each) do
        @mail = Mail::Message.new
      end

      it "should return the to field" do
        @mail.to "mikel"
        @mail.to.should == ["mikel"]
      end

      it "should return the from field" do
        @mail.from "bob"
        @mail.from.should == ["bob"]
      end

      it "should return the subject" do
        @mail.subject "Hello!"
        @mail.subject.should == "Hello!"
      end

      it "should return the body decoded with to_s" do
        @mail.body "email message\r\n"
        @mail.body.to_s.should == "email message\n"
      end

      it "should return the body encoded if asked for" do
        @mail.body "email message\r\n"
        @mail.body.encoded.should == "email message\r\n"
      end

      it "should return the body decoded if asked for" do
        @mail.body "email message\r\n"
        @mail.body.decoded.should == "email message\n"
      end
    end
    
    describe "setting arbitrary headers" do

      before(:each) do
        @mail = Mail::Message.new
      end

      it "should allow you to set them" do
        doing {@mail['foo'] = 1234}.should_not raise_error
      end
      
      it "should allow you to read arbitrary headers" do
        @mail['foo'] = 1234
        @mail['foo'].value.to_s.should == '1234'
      end
      
      it "should instantiate a new Header" do
        @mail['foo'] = 1234
        @mail.header_fields.first.class.should == Mail::Field
      end
    end
    
    describe "replacing header values" do
    
      it "should allow you to replace a from field" do
        mail = Mail.new
        mail.from.should == nil
        mail.from = 'mikel@test.lindsaar.net'
        mail.from.should == ['mikel@test.lindsaar.net']
        mail.from = 'bob@test.lindsaar.net'
        mail.from.should == ['bob@test.lindsaar.net']
      end
    
      it "should maintain the class of the field" do
        mail = Mail.new
        mail.from = 'mikel@test.lindsaar.net'
        mail[:from].field.class.should == Mail::FromField
        mail.from = 'bob@test.lindsaar.net'
        mail[:from].field.class.should == Mail::FromField
      end
    end
    
    describe "setting headers" do
      
      it "should accept them in block form" do
        message = Mail.new do
          bcc           'mikel@bcc.lindsaar.net'
          cc            'mikel@cc.lindsaar.net'
          comments      'this is a comment'
          date          '12 Aug 2009 00:00:01 GMT'
          from          'mikel@from.lindsaar.net'
          in_reply_to   '<1234@in_reply_to.lindsaar.net>'
          keywords      'test, "of the new mail", system'
          message_id    '<1234@message_id.lindsaar.net>'
          received      'from machine.example by x.y.test; 12 Aug 2009 00:00:02 GMT'
          references    '<1234@references.lindsaar.net>'
          reply_to      'mikel@reply-to.lindsaar.net'
          resent_bcc    'mikel@resent-bcc.lindsaar.net'
          resent_cc     'mikel@resent-cc.lindsaar.net'
          resent_date   '12 Aug 2009 00:00:03 GMT'
          resent_from   'mikel@resent-from.lindsaar.net'
          resent_message_id '<1234@resent_message_id.lindsaar.net>'
          resent_sender 'mikel@resent-sender.lindsaar.net'
          resent_to     'mikel@resent-to.lindsaar.net'
          sender        'mikel@sender.lindsaar.net'
          subject       'Hello there Mikel'
          to            'mikel@to.lindsaar.net'
          content_type  'text/plain; charset=UTF-8'
          content_transfer_encoding '7bit'
          content_description       'This is a test'
          content_disposition       'attachment; filename=File'
          content_id                '<1234@message_id.lindsaar.net>'
          mime_version  '1.0'
          body          'This is a body of text'
        end
        
        message.bcc.should           == ['mikel@bcc.lindsaar.net']
        message.cc.should            == ['mikel@cc.lindsaar.net']
        message.comments.should      == 'this is a comment'
        message.date.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.should          == ['mikel@from.lindsaar.net']
        message.in_reply_to.should   == '1234@in_reply_to.lindsaar.net'
        message.keywords.should      == ["test", "of the new mail", "system"]
        message.message_id.should    == '1234@message_id.lindsaar.net'
        message.received.date_time.should      == DateTime.parse('12 Aug 2009 00:00:02 GMT')
        message.references.should    == '1234@references.lindsaar.net'
        message.reply_to.should      == ['mikel@reply-to.lindsaar.net']
        message.resent_bcc.should    == ['mikel@resent-bcc.lindsaar.net']
        message.resent_cc.should     == ['mikel@resent-cc.lindsaar.net']
        message.resent_date.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.should   == ['mikel@resent-from.lindsaar.net']
        message.resent_message_id.should == '1234@resent_message_id.lindsaar.net'
        message.resent_sender.should == ['mikel@resent-sender.lindsaar.net']
        message.resent_to.should     == ['mikel@resent-to.lindsaar.net']
        message.sender.should        == 'mikel@sender.lindsaar.net'
        message.subject.should       == 'Hello there Mikel'
        message.to.should            == ['mikel@to.lindsaar.net']
        message.content_type.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.should == '7bit'
        message.content_description.should       == 'This is a test'
        message.content_disposition.should       == 'attachment; filename=File'
        message.content_id.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end

      it "should accept them in assignment form" do
        message = Mail.new
        message.bcc =           'mikel@bcc.lindsaar.net'
        message.cc =            'mikel@cc.lindsaar.net'
        message.comments =      'this is a comment'
        message.date =          '12 Aug 2009 00:00:01 GMT'
        message.from =          'mikel@from.lindsaar.net'
        message.in_reply_to =   '<1234@in_reply_to.lindsaar.net>'
        message.keywords =      'test, "of the new mail", system'
        message.message_id =    '<1234@message_id.lindsaar.net>'
        message.received =      'from machine.example by x.y.test; 12 Aug 2009 00:00:02 GMT'
        message.references =    '<1234@references.lindsaar.net>'
        message.reply_to =      'mikel@reply-to.lindsaar.net'
        message.resent_bcc =    'mikel@resent-bcc.lindsaar.net'
        message.resent_cc =     'mikel@resent-cc.lindsaar.net'
        message.resent_date =   '12 Aug 2009 00:00:03 GMT'
        message.resent_from =   'mikel@resent-from.lindsaar.net'
        message.resent_message_id = '<1234@resent_message_id.lindsaar.net>'
        message.resent_sender = 'mikel@resent-sender.lindsaar.net'
        message.resent_to =     'mikel@resent-to.lindsaar.net'
        message.sender =        'mikel@sender.lindsaar.net'
        message.subject =       'Hello there Mikel'
        message.to =            'mikel@to.lindsaar.net'
        message.content_type =  'text/plain; charset=UTF-8'
        message.content_transfer_encoding = '7bit'
        message.content_description =       'This is a test'
        message.content_disposition =       'attachment; filename=File'
        message.content_id =                '<1234@message_id.lindsaar.net>'
        message.mime_version =  '1.0'
        message.body =          'This is a body of text'

        message.bcc.should           == ['mikel@bcc.lindsaar.net']
        message.cc.should            == ['mikel@cc.lindsaar.net']
        message.comments.should      == 'this is a comment'
        message.date.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.should          == ['mikel@from.lindsaar.net']
        message.in_reply_to.should   == '1234@in_reply_to.lindsaar.net'
        message.keywords.should      == ["test", "of the new mail", "system"]
        message.message_id.should    == '1234@message_id.lindsaar.net'
        message.received.date_time.should      == DateTime.parse('12 Aug 2009 00:00:02 GMT')
        message.references.should    == '1234@references.lindsaar.net'
        message.reply_to.should      == ['mikel@reply-to.lindsaar.net']
        message.resent_bcc.should    == ['mikel@resent-bcc.lindsaar.net']
        message.resent_cc.should     == ['mikel@resent-cc.lindsaar.net']
        message.resent_date.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.should   == ['mikel@resent-from.lindsaar.net']
        message.resent_message_id.should == '1234@resent_message_id.lindsaar.net'
        message.resent_sender.should == ['mikel@resent-sender.lindsaar.net']
        message.resent_to.should     == ['mikel@resent-to.lindsaar.net']
        message.sender.should        == 'mikel@sender.lindsaar.net'
        message.subject.should       == 'Hello there Mikel'
        message.to.should            == ['mikel@to.lindsaar.net']
        message.content_type.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.should == '7bit'
        message.content_description.should       == 'This is a test'
        message.content_disposition.should       == 'attachment; filename=File'
        message.content_id.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end
      
      it "should accept them in key, value form as symbols" do
        message = Mail.new
        message[:bcc] =           'mikel@bcc.lindsaar.net'
        message[:cc] =            'mikel@cc.lindsaar.net'
        message[:comments] =      'this is a comment'
        message[:date] =          '12 Aug 2009 00:00:01 GMT'
        message[:from] =          'mikel@from.lindsaar.net'
        message[:in_reply_to] =   '<1234@in_reply_to.lindsaar.net>'
        message[:keywords] =      'test, "of the new mail", system'
        message[:message_id] =    '<1234@message_id.lindsaar.net>'
        message[:received] =      'from machine.example by x.y.test; 12 Aug 2009 00:00:02 GMT'
        message[:references] =    '<1234@references.lindsaar.net>'
        message[:reply_to] =      'mikel@reply-to.lindsaar.net'
        message[:resent_bcc] =    'mikel@resent-bcc.lindsaar.net'
        message[:resent_cc] =     'mikel@resent-cc.lindsaar.net'
        message[:resent_date] =   '12 Aug 2009 00:00:03 GMT'
        message[:resent_from] =   'mikel@resent-from.lindsaar.net'
        message[:resent_message_id] = '<1234@resent_message_id.lindsaar.net>'
        message[:resent_sender] = 'mikel@resent-sender.lindsaar.net'
        message[:resent_to] =     'mikel@resent-to.lindsaar.net'
        message[:sender] =        'mikel@sender.lindsaar.net'
        message[:subject] =       'Hello there Mikel'
        message[:to] =            'mikel@to.lindsaar.net'
        message[:content_type] =  'text/plain; charset=UTF-8'
        message[:content_transfer_encoding] = '7bit'
        message[:content_description] =       'This is a test'
        message[:content_disposition] =       'attachment; filename=File'
        message[:content_id] =                '<1234@message_id.lindsaar.net>'
        message[:mime_version]=  '1.0'
        message[:body] =          'This is a body of text'
        
        message.bcc.should           == ['mikel@bcc.lindsaar.net']
        message.cc.should            == ['mikel@cc.lindsaar.net']
        message.comments.should      == 'this is a comment'
        message.date.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.should          == ['mikel@from.lindsaar.net']
        message.in_reply_to.should   == '1234@in_reply_to.lindsaar.net'
        message.keywords.should      == ["test", "of the new mail", "system"]
        message.message_id.should    == '1234@message_id.lindsaar.net'
        message.received.date_time.should      == DateTime.parse('12 Aug 2009 00:00:02 GMT')
        message.references.should    == '1234@references.lindsaar.net'
        message.reply_to.should      == ['mikel@reply-to.lindsaar.net']
        message.resent_bcc.should    == ['mikel@resent-bcc.lindsaar.net']
        message.resent_cc.should     == ['mikel@resent-cc.lindsaar.net']
        message.resent_date.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.should   == ['mikel@resent-from.lindsaar.net']
        message.resent_message_id.should == '1234@resent_message_id.lindsaar.net'
        message.resent_sender.should == ['mikel@resent-sender.lindsaar.net']
        message.resent_to.should     == ['mikel@resent-to.lindsaar.net']
        message.sender.should        == 'mikel@sender.lindsaar.net'
        message.subject.should       == 'Hello there Mikel'
        message.to.should            == ['mikel@to.lindsaar.net']
        message.content_type.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.should == '7bit'
        message.content_description.should       == 'This is a test'
        message.content_disposition.should       == 'attachment; filename=File'
        message.content_id.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end
      
      it "should accept them in key, value form as strings" do
        message = Mail.new
        message['bcc'] =           'mikel@bcc.lindsaar.net'
        message['cc'] =            'mikel@cc.lindsaar.net'
        message['comments'] =      'this is a comment'
        message['date'] =          '12 Aug 2009 00:00:01 GMT'
        message['from'] =          'mikel@from.lindsaar.net'
        message['in_reply_to'] =   '<1234@in_reply_to.lindsaar.net>'
        message['keywords'] =      'test, "of the new mail", system'
        message['message_id'] =    '<1234@message_id.lindsaar.net>'
        message['received'] =      'from machine.example by x.y.test; 12 Aug 2009 00:00:02 GMT'
        message['references'] =    '<1234@references.lindsaar.net>'
        message['reply_to'] =      'mikel@reply-to.lindsaar.net'
        message['resent_bcc'] =    'mikel@resent-bcc.lindsaar.net'
        message['resent_cc'] =     'mikel@resent-cc.lindsaar.net'
        message['resent_date'] =   '12 Aug 2009 00:00:03 GMT'
        message['resent_from'] =   'mikel@resent-from.lindsaar.net'
        message['resent_message_id'] = '<1234@resent_message_id.lindsaar.net>'
        message['resent_sender'] = 'mikel@resent-sender.lindsaar.net'
        message['resent_to'] =     'mikel@resent-to.lindsaar.net'
        message['sender'] =        'mikel@sender.lindsaar.net'
        message['subject'] =       'Hello there Mikel'
        message['to'] =            'mikel@to.lindsaar.net'
        message['content_type'] =  'text/plain; charset=UTF-8'
        message['content_transfer_encoding'] = '7bit'
        message['content_description'] =       'This is a test'
        message['content_disposition'] =       'attachment; filename=File'
        message['content_id'] =                '<1234@message_id.lindsaar.net>'
        message['mime_version'] =  '1.0'
        message['body'] =          'This is a body of text'
        
        message.bcc.should           == ['mikel@bcc.lindsaar.net']
        message.cc.should            == ['mikel@cc.lindsaar.net']
        message.comments.should      == 'this is a comment'
        message.date.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.should          == ['mikel@from.lindsaar.net']
        message.in_reply_to.should   == '1234@in_reply_to.lindsaar.net'
        message.keywords.should      == ["test", "of the new mail", "system"]
        message.message_id.should    == '1234@message_id.lindsaar.net'
        message.received.date_time.should      == DateTime.parse('12 Aug 2009 00:00:02 GMT')
        message.references.should    == '1234@references.lindsaar.net'
        message.reply_to.should      == ['mikel@reply-to.lindsaar.net']
        message.resent_bcc.should    == ['mikel@resent-bcc.lindsaar.net']
        message.resent_cc.should     == ['mikel@resent-cc.lindsaar.net']
        message.resent_date.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.should   == ['mikel@resent-from.lindsaar.net']
        message.resent_message_id.should == '1234@resent_message_id.lindsaar.net'
        message.resent_sender.should == ['mikel@resent-sender.lindsaar.net']
        message.resent_to.should     == ['mikel@resent-to.lindsaar.net']
        message.sender.should        == 'mikel@sender.lindsaar.net'
        message.subject.should       == 'Hello there Mikel'
        message.to.should            == ['mikel@to.lindsaar.net']
        message.content_type.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.should == '7bit'
        message.content_description.should       == 'This is a test'
        message.content_disposition.should       == 'attachment; filename=File'
        message.content_id.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end
      
      it "should accept them as a hash with symbols" do
        message = Mail.new({
          :bcc =>           'mikel@bcc.lindsaar.net',
          :cc =>            'mikel@cc.lindsaar.net',
          :comments =>      'this is a comment',
          :date =>          '12 Aug 2009 00:00:01 GMT',
          :from =>          'mikel@from.lindsaar.net',
          :in_reply_to =>   '<1234@in_reply_to.lindsaar.net>',
          :keywords =>      'test, "of the new mail", system',
          :message_id =>    '<1234@message_id.lindsaar.net>',
          :received =>      'from machine.example by x.y.test; 12 Aug 2009 00:00:02 GMT',
          :references =>    '<1234@references.lindsaar.net>',
          :reply_to =>      'mikel@reply-to.lindsaar.net',
          :resent_bcc =>    'mikel@resent-bcc.lindsaar.net',
          :resent_cc =>     'mikel@resent-cc.lindsaar.net',
          :resent_date =>   '12 Aug 2009 00:00:03 GMT',
          :resent_from =>   'mikel@resent-from.lindsaar.net',
          :resent_message_id => '<1234@resent_message_id.lindsaar.net>',
          :resent_sender => 'mikel@resent-sender.lindsaar.net',
          :resent_to =>     'mikel@resent-to.lindsaar.net',
          :sender =>        'mikel@sender.lindsaar.net',
          :subject =>       'Hello there Mikel',
          :to =>            'mikel@to.lindsaar.net',
          :content_type =>  'text/plain; charset=UTF-8',
          :content_transfer_encoding => '7bit',
          :content_description =>       'This is a test',
          :content_disposition =>       'attachment; filename=File',
          :content_id =>                '<1234@message_id.lindsaar.net>',
          :mime_version =>  '1.0',
          :body =>          'This is a body of text'
        })
        
        message.bcc.should           == ['mikel@bcc.lindsaar.net']
        message.cc.should            == ['mikel@cc.lindsaar.net']
        message.comments.should      == 'this is a comment'
        message.date.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.should          == ['mikel@from.lindsaar.net']
        message.in_reply_to.should   == '1234@in_reply_to.lindsaar.net'
        message.keywords.should      == ["test", "of the new mail", "system"]
        message.message_id.should    == '1234@message_id.lindsaar.net'
        message.received.date_time.should      == DateTime.parse('12 Aug 2009 00:00:02 GMT')
        message.references.should    == '1234@references.lindsaar.net'
        message.reply_to.should      == ['mikel@reply-to.lindsaar.net']
        message.resent_bcc.should    == ['mikel@resent-bcc.lindsaar.net']
        message.resent_cc.should     == ['mikel@resent-cc.lindsaar.net']
        message.resent_date.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.should   == ['mikel@resent-from.lindsaar.net']
        message.resent_message_id.should == '1234@resent_message_id.lindsaar.net'
        message.resent_sender.should == ['mikel@resent-sender.lindsaar.net']
        message.resent_to.should     == ['mikel@resent-to.lindsaar.net']
        message.sender.should        == 'mikel@sender.lindsaar.net'
        message.subject.should       == 'Hello there Mikel'
        message.to.should            == ['mikel@to.lindsaar.net']
        message.content_type.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.should == '7bit'
        message.content_description.should       == 'This is a test'
        message.content_disposition.should       == 'attachment; filename=File'
        message.content_id.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end
      
      it "should accept them as a hash with strings" do
        message = Mail.new({
          'bcc' =>           'mikel@bcc.lindsaar.net',
          'cc' =>            'mikel@cc.lindsaar.net',
          'comments' =>      'this is a comment',
          'date' =>          '12 Aug 2009 00:00:01 GMT',
          'from' =>          'mikel@from.lindsaar.net',
          'in_reply_to' =>   '<1234@in_reply_to.lindsaar.net>',
          'keywords' =>      'test, "of the new mail", system',
          'message_id' =>    '<1234@message_id.lindsaar.net>',
          'received' =>      'from machine.example by x.y.test; 12 Aug 2009 00:00:02 GMT',
          'references' =>    '<1234@references.lindsaar.net>',
          'reply_to' =>      'mikel@reply-to.lindsaar.net',
          'resent_bcc' =>    'mikel@resent-bcc.lindsaar.net',
          'resent_cc' =>     'mikel@resent-cc.lindsaar.net',
          'resent_date' =>   '12 Aug 2009 00:00:03 GMT',
          'resent_from' =>   'mikel@resent-from.lindsaar.net',
          'resent_message_id' => '<1234@resent_message_id.lindsaar.net>',
          'resent_sender' => 'mikel@resent-sender.lindsaar.net',
          'resent_to' =>     'mikel@resent-to.lindsaar.net',
          'sender' =>        'mikel@sender.lindsaar.net',
          'subject' =>       'Hello there Mikel',
          'to' =>            'mikel@to.lindsaar.net',
          'content_type' =>  'text/plain; charset=UTF-8',
          'content_transfer_encoding' => '7bit',
          'content_description' =>       'This is a test',
          'content_disposition' =>       'attachment; filename=File',
          'content_id' =>                '<1234@message_id.lindsaar.net>',
          'mime_version' =>  '1.0',
          'body' =>          'This is a body of text'
        })
        
        message.bcc.should           == ['mikel@bcc.lindsaar.net']
        message.cc.should            == ['mikel@cc.lindsaar.net']
        message.comments.should      == 'this is a comment'
        message.date.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.should          == ['mikel@from.lindsaar.net']
        message.in_reply_to.should   == '1234@in_reply_to.lindsaar.net'
        message.keywords.should      == ["test", "of the new mail", "system"]
        message.message_id.should    == '1234@message_id.lindsaar.net'
        message.received.date_time.should      == DateTime.parse('12 Aug 2009 00:00:02 GMT')
        message.references.should    == '1234@references.lindsaar.net'
        message.reply_to.should      == ['mikel@reply-to.lindsaar.net']
        message.resent_bcc.should    == ['mikel@resent-bcc.lindsaar.net']
        message.resent_cc.should     == ['mikel@resent-cc.lindsaar.net']
        message.resent_date.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.should   == ['mikel@resent-from.lindsaar.net']
        message.resent_message_id.should == '1234@resent_message_id.lindsaar.net'
        message.resent_sender.should == ['mikel@resent-sender.lindsaar.net']
        message.resent_to.should     == ['mikel@resent-to.lindsaar.net']
        message.sender.should        == 'mikel@sender.lindsaar.net'
        message.subject.should       == 'Hello there Mikel'
        message.to.should            == ['mikel@to.lindsaar.net']
        message.content_type.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.should == '7bit'
        message.content_description.should       == 'This is a test'
        message.content_disposition.should       == 'attachment; filename=File'
        message.content_id.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end

      it "should let you set custom headers with a :headers => {hash}" do
        message = Mail.new(:headers => {'custom-header' => 'mikel'})
        message['custom-header'].decoded.should == 'mikel'
      end
      
      it "should assign the body to a part on creation" do
        message = Mail.new do
          part({:content_type=>"multipart/alternative", :content_disposition=>"inline", :body=>"Nothing to see here."})
        end
        message.parts.first.body.decoded.should == "Nothing to see here."
      end
      
      it "should not overwrite bodies on creation" do
        message = Mail.new do
          part({:content_type=>"multipart/alternative", :content_disposition=>"inline", :body=>"Nothing to see here."}) do |p|
            p.part :content_type => "text/html", :body => "<b>test</b> HTML<br/>"
          end
        end
        message.parts.first.parts[0].body.decoded.should == "Nothing to see here."
        message.parts.first.parts[1].body.decoded.should == "<b>test</b> HTML<br/>"
        message.encoded.should match(%r{Nothing to see here\.})
        message.encoded.should match(%r{<b>test</b> HTML<br/>})
      end
      
      it "should allow you to init on an array of addresses from a hash" do
        mail = Mail.new(:to => ['test1@lindsaar.net', 'Mikel <test2@lindsaar.net>'])
        mail.to.should == ['test1@lindsaar.net', 'test2@lindsaar.net']
      end
      
      it "should allow you to init on an array of addresses directly" do
        mail = Mail.new
        mail.to = ['test1@lindsaar.net', 'Mikel <test2@lindsaar.net>']
        mail.to.should == ['test1@lindsaar.net', 'test2@lindsaar.net']
      end
      
      it "should allow you to init on an array of addresses directly" do
        mail = Mail.new
        mail[:to] = ['test1@lindsaar.net', 'Mikel <test2@lindsaar.net>']
        mail.to.should == ['test1@lindsaar.net', 'test2@lindsaar.net']
      end
      
    end
    
  end
    
  describe "handling missing required fields:" do
    
    describe "every email" do
    
      describe "Message-ID" do
        it "should say if it has a message id" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.should_not be_has_message_id
        end

        it "should preserve any message id that you pass it if add_message_id is called explicitly" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_message_id("<ThisIsANonUniqueMessageId@me.com>")
          mail.to_s.should =~ /Message-ID: <ThisIsANonUniqueMessageId@me.com>\r\n/
        end

        it "should generate a random message ID if nothing is passed to add_message_id" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_message_id
          fqdn ||= ::Socket.gethostname
          mail.to_s.should =~ /Message-ID: <[\d\w_]+@#{fqdn}.mail>\r\n/
        end

        it "should make an email and inject a message ID if none was set if told to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          (mail.to_s =~ /Message-ID: <.+@.+.mail>/i).should_not be_nil      
        end

        it "should add the message id to the message permanently once sent to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s
          mail.should be_has_message_id
        end
      
        it "should add a body part if it is missing" do
          mail = Mail.new
          mail.to_s
          mail.body.class.should == Mail::Body
        end
      end

      describe "Date" do
        it "should say if it has a date" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.should_not be_has_date
        end

        it "should preserve any date that you pass it if add_date is called explicitly" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_date("Mon, 24 Nov 1997 14:22:01 -0800")
          mail.to_s.should =~ /Date: Mon, 24 Nov 1997 14:22:01 -0800/
        end

        it "should generate a current date if nothing is passed to add_date" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_date
          mail.to_s.should =~ /Date: \w{3}, [\s\d]\d \w{3} \d{4} \d{2}:\d{2}:\d{2} [-+]?\d{4}\r\n/
        end

        it "should make an email and inject a date if none was set if told to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s.should =~ /Date: \w{3}, [\s\d]\d \w{3} \d{4} \d{2}:\d{2}:\d{2} [-+]?\d{4}\r\n/
        end

        it "should add the date to the message permanently once sent to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s
          mail.should be_has_date
        end
      end

    end
    
    describe "mime emails" do
      
      describe "mime-version" do
        it "should say if it has a mime-version" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.should_not be_has_mime_version
        end

        it "should preserve any mime version that you pass it if add_mime_version is called explicitly" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_mime_version("3.0 (This is an unreal version number)")
          mail.to_s.should =~ /Mime-Version: 3.0 \(This is an unreal version number\)\r\n/
        end

        it "should generate a mime version if nothing is passed to add_date" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_mime_version
          mail.to_s.should =~ /Mime-Version: 1.0\r\n/
        end

        it "should make an email and inject a mime_version if none was set if told to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s.should =~ /Mime-Version: 1.0\r\n/
        end

        it "should add the mime version to the message permanently once sent to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s
          mail.should be_has_mime_version
        end
      end
      
      describe "content type" do
      
        it "should say if it has a content type" do
          mail = Mail.new('Content-Type: text/plain')
          mail.should be_has_content_type
        end

        it "should say if it does not have a content type" do
          mail = Mail.new
          mail.should_not be_has_content_type
        end

        it "should say if it has a charset" do
          mail = Mail.new('Content-Type: text/plain; charset=US-ASCII')
          mail.should be_has_charset
        end

        it "should say if it has a charset" do
          mail = Mail.new('Content-Type: text/plain')
          mail.should_not be_has_charset
        end

        it "should not raise a warning if there is no charset defined and only US-ASCII chars" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          STDERR.should_not_receive(:puts)
          mail.to_s 
        end

        it "should set the content type to text/plain; charset=us-ascii" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          mail.to_s =~ %r{Content-Type: text/plain; charset=US-ASCII}
        end
        
        it "should not set the charset if the file is an attachment" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          mail.content_disposition = 'attachment; filename="foo.jpg"'
          mail.to_s =~ %r{Content-Type: text/plain;\r\n}
        end

        it "should raise a warning if there is no content type and there is non ascii chars and default to text/plain, UTF-8" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_transfer_encoding = "8bit"
          STDERR.should_receive(:puts).with(/Non US-ASCII detected and no charset defined.\nDefaulting to UTF-8, set your own if this is incorrect./m)
          mail.to_s =~ %r{Content-Type: text/plain; charset=UTF-8}
        end

        it "should raise a warning if there is no charset parameter and there is non ascii chars and default to text/plain, UTF-8" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_type = "text/plain"
          mail.content_transfer_encoding = "8bit"
          STDERR.should_receive(:puts).with(/Non US-ASCII detected and no charset defined.\nDefaulting to UTF-8, set your own if this is incorrect./m)
          mail.to_s =~ %r{Content-Type: text/plain; charset=UTF-8}
        end

        it "should not raise a warning if there is a charset defined and there is non ascii chars" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_transfer_encoding = "8bit"
          mail.content_type = "text/plain; charset=UTF-8"
          STDERR.should_not_receive(:puts)
          mail.to_s 
        end
        
        it "should be able to set a content type with an array and hash" do
          mail = Mail.new
          mail.content_type = ["text", "plain", { "charset" => 'US-ASCII' }]
          mail[:content_type].encoded.should == %Q[Content-Type: text/plain;\r\n\tcharset="US-ASCII";\r\n]
          mail.content_type_parameters.should == {"charset" => "US-ASCII"}
        end
        
        it "should be able to set a content type with an array and hash with a non-usascii field" do
          mail = Mail.new
          mail.content_type = ["text", "plain", { "charset" => 'UTF-8' }]
          mail[:content_type].encoded.should == %Q[Content-Type: text/plain;\r\n\tcharset="UTF-8";\r\n]
          mail.content_type_parameters.should == {"charset" => "UTF-8"}
        end

        it "should allow us to specify a content type in a block" do
          mail = Mail.new { content_type ["text", "plain", { "charset" => "UTF-8" }] }
          mail.content_type_parameters.should == {"charset" => "UTF-8"}
        end
        
      end
      
      describe "content-transfer-encoding" do

        it "should not raise a warning if there is no content-transfer-encoding and only US-ASCII chars" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          STDERR.should_not_receive(:puts)
          mail.to_s 
        end

        it "should set the content-transfer-encoding to 7bit" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          mail.to_s =~ %r{Content-Transfer-Encoding: 7bit}
        end

        it "should raise a warning if there is no content-transfer-encoding and there is non ascii chars and default to 8bit" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_type = "text/plain; charset=utf-8"
          mail.should be_has_content_type
          mail.should be_has_charset
          STDERR.should_receive(:puts).with(/Non US-ASCII detected and no content-transfer-encoding defined.\nDefaulting to 8bit, set your own if this is incorrect./m)
          mail.to_s =~ %r{Content-Transfer-Encoding: 8bit}
        end

        it "should not raise a warning if there is a content-transfer-encoding defined and there is non ascii chars" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_type = "text/plain; charset=utf-8"
          mail.content_transfer_encoding = "8bit"
          STDERR.should_not_receive(:puts)
          mail.to_s 
        end

      end
      
    end
    
  end

  describe "output" do
    
    it "should make an email and allow you to call :to_s on it to get a string" do
      mail = Mail.new do
           from 'mikel@test.lindsaar.net'
             to 'you@test.lindsaar.net'
        subject 'This is a test email'
           body 'This is a body of the email'
      end
      
      mail.to_s.should =~ /From: mikel@test.lindsaar.net\r\n/
      mail.to_s.should =~ /To: you@test.lindsaar.net\r\n/
      mail.to_s.should =~ /Subject: This is a test email\r\n/
      mail.to_s.should =~ /This is a body of the email/

    end

    it "should raise an error and message if you try and call decoded" do
      mail = Mail.new
      doing { mail.decoded }.should raise_error(NoMethodError, 'Can not decode an entire message, try calling #decoded on the various fields and body or parts if it is a multipart message.')
    end
    
    describe "decoding bodies" do

      it "should not change a body on decode if not given an encoding type to decode" do
        mail = Mail.new do
          body "The=3Dbody"
        end
        mail.body.decoded.should == "The=3Dbody"
        mail.body.encoded.should == "The=3Dbody"
      end

      it "should change a body on decode if given an encoding type to decode" do
        mail = Mail.new do
          content_transfer_encoding 'quoted-printable'
          body "The=3Dbody"
        end
        mail.body.decoded.should == "The=body"
        mail.body.encoded.should == "The=3Dbody"
      end

      it "should change a body on decode if given an encoding type to decode" do
        mail = Mail.new do
          content_transfer_encoding 'base64'
          body "VGhlIGJvZHk=\n"
        end
        mail.body.decoded.should == "The body"
        mail.body.encoded.should == "VGhlIGJvZHk=\r\n"
      end

    end
    
  end
  
  describe "helper methods" do
    
    describe "==" do
      it "should be implemented" do
        doing { Mail.new == Mail.new }.should_not raise_error
      end

      it "should ignore the message id value if both have a nil message id" do
        m1 = Mail.new("To: mikel@test.lindsaar.net\r\nSubject: Yo!\r\n\r\nHello there")
        m2 = Mail.new("To: mikel@test.lindsaar.net\r\nSubject: Yo!\r\n\r\nHello there")
        m1.should == m2
      end

      it "should ignore the message id value if self has a nil message id" do
        m1 = Mail.new("To: mikel@test.lindsaar.net\r\nSubject: Yo!\r\n\r\nHello there")
        m2 = Mail.new("To: mikel@test.lindsaar.net\r\nMessage-ID: <1234@test.lindsaar.net>\r\nSubject: Yo!\r\n\r\nHello there")
        m1.should == m2
      end

      it "should ignore the message id value if other has a nil message id" do
        m1 = Mail.new("To: mikel@test.lindsaar.net\r\nMessage-ID: <1234@test.lindsaar.net>\r\nSubject: Yo!\r\n\r\nHello there")
        m2 = Mail.new("To: mikel@test.lindsaar.net\r\nSubject: Yo!\r\n\r\nHello there")
        m1.should == m2
      end

      it "should not be == if both emails have different Message IDs" do
        m1 = Mail.new("To: mikel@test.lindsaar.net\r\nMessage-ID: <4321@test.lindsaar.net>\r\nSubject: Yo!\r\n\r\nHello there")
        m2 = Mail.new("To: mikel@test.lindsaar.net\r\nMessage-ID: <1234@test.lindsaar.net>\r\nSubject: Yo!\r\n\r\nHello there")
        m1.should_not == m2
      end
      
      it "should preserve the message id of self if set" do
        m1 = Mail.new("To: mikel@test.lindsaar.net\r\nMessage-ID: <1234@test.lindsaar.net>\r\nSubject: Yo!\r\n\r\nHello there")
        m2 = Mail.new("To: mikel@test.lindsaar.net\r\nSubject: Yo!\r\n\r\nHello there")
        m1 == m2
        m1.message_id.should == '1234@test.lindsaar.net'
      end
      
      it "should preserve the message id of other if set" do
        m1 = Mail.new("To: mikel@test.lindsaar.net\r\nSubject: Yo!\r\n\r\nHello there")
        m2 = Mail.new("To: mikel@test.lindsaar.net\r\nMessage-ID: <1234@test.lindsaar.net>\r\nSubject: Yo!\r\n\r\nHello there")
        m1 == m2
        m2.message_id.should == '1234@test.lindsaar.net'
      end
      
      it "should preserve the message id of both if set" do
        m1 = Mail.new("To: mikel@test.lindsaar.net\r\nMessage-ID: <4321@test.lindsaar.net>\r\nSubject: Yo!\r\n\r\nHello there")
        m2 = Mail.new("To: mikel@test.lindsaar.net\r\nMessage-ID: <1234@test.lindsaar.net>\r\nSubject: Yo!\r\n\r\nHello there")
        m1 == m2
        m1.message_id.should == '4321@test.lindsaar.net'
        m2.message_id.should == '1234@test.lindsaar.net'
      end
    end
    
    it "should implement the spaceship operator on the date field" do
      now = Time.now
      mail1 = Mail.new do
        date(now)
      end
      mail2 = Mail.new do
        date(now - 10) # Make mail2 10 seconds 'older'
      end
      [mail2, mail1].sort.should == [mail2, mail1]
    end
    
    it "should have a destinations method" do
      mail = Mail.new do
        to 'mikel@test.lindsaar.net'
        cc 'bob@test.lindsaar.net'
        bcc 'sam@test.lindsaar.net'
      end
      mail.destinations.length.should == 3
    end

    it "should have a from_addrs method" do
      mail = Mail.new do
        from 'mikel@test.lindsaar.net'
      end
      mail.from_addrs.length.should == 1
    end

    it "should have a from_addrs method that is empty if nil" do
      mail = Mail.new do
      end
      mail.from_addrs.length.should == 0
    end

    it "should have a to_addrs method" do
      mail = Mail.new do
        to 'mikel@test.lindsaar.net'
      end
      mail.to_addrs.length.should == 1
    end

    it "should have a to_addrs method that is empty if nil" do
      mail = Mail.new do
      end
      mail.to_addrs.length.should == 0
    end

    it "should have a cc_addrs method" do
      mail = Mail.new do
        cc 'bob@test.lindsaar.net'
      end
      mail.cc_addrs.length.should == 1
    end

    it "should have a cc_addrs method that is empty if nil" do
      mail = Mail.new do
      end
      mail.cc_addrs.length.should == 0
    end

    it "should have a bcc_addrs method" do
      mail = Mail.new do
        bcc 'sam@test.lindsaar.net'
      end
      mail.bcc_addrs.length.should == 1
    end

    it "should have a bcc_addrs method that is empty if nil" do
      mail = Mail.new do
      end
      mail.bcc_addrs.length.should == 0
    end

    it "should give destinations even if some of the fields are blank" do
      mail = Mail.new do
        to 'mikel@test.lindsaar.net'
      end
      mail.destinations.length.should == 1
    end
    
    it "should be able to encode with only one destination" do
      mail = Mail.new do
        to 'mikel@test.lindsaar.net'
      end
      mail.encoded
    end

  end
  
  describe "nested parts" do
    it "should provide a way to instantiate a new part as you go down" do
      mail = Mail.new do
        to           'mikel@test.lindsaar.net'
        subject      "nested multipart"
        from         "test@example.com"
        content_type "multipart/mixed"

        part :content_type => "multipart/alternative", :content_disposition => "inline", :headers => { "foo" => "bar" } do |p|
          p.part :content_type => "text/plain", :body => "test text\nline #2"
          p.part :content_type => "text/html", :body => "<b>test</b> HTML<br/>\nline #2"
        end

      end

      mail.parts.first.should be_multipart
      mail.parts.first.parts.length.should == 2
      mail.parts.first.parts[0][:content_type].string.should == "text/plain"
      mail.parts.first.parts[0].body.decoded.should == "test text\nline #2"
      mail.parts.first.parts[1][:content_type].string.should == "text/html"
      mail.parts.first.parts[1].body.decoded.should == "<b>test</b> HTML<br/>\nline #2"
    end
  end
  
  describe "deliver" do
    it "should return self after delivery" do
      mail = Mail.new
      mail.perform_deliveries = false
      mail.deliver.should == mail
    end
  end
end
