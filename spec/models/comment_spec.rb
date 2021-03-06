require File.dirname(__FILE__) + '/../spec_helper'

describe Comment do

  describe "factories" do
    it "should generate a valid comment" do
      @project = Factory(:project)
      @user = @project.user
      comment = Factory.build(:comment, :project => @project, :user => @user, :target => @project)
      comment.save.should be_true
      comment.user.should == @user
      comment.target.should == @project    
      @project.comments.last.should == comment
      @user.comments.last.should == comment
    end
  end

  describe "posting to a project" do
    before do
      @project = Factory(:project)
      @user = @project.user
    end
    
    it "should add it as an activity" do
      comment = Factory(:comment, :project => @project, :user => @user, :target => @project)
      @project.reload.activities.first.target.should == comment
    end
    
    it "should notify mentioned @user in the project" do
      @mentioned = Factory(:user)
      @project.add_user(@mentioned)
      @mentioned.notify_mentions = true
      @mentioned.save!
      comment = Factory.build(:comment, :project => @project, :user => @user, :target => @project,
        :body => "Hey @#{@mentioned.login}, how are you?")
      Emailer.should_receive(:deliver_notify_comment).with(@mentioned, @project, comment).once
      comment.save!
    end

    it "should not notify mentions to @user if he doesn't allow notifications" do
      @mentioned = Factory(:user)
      @project.add_user(@mentioned)
      @mentioned.notify_mentions = false
      @mentioned.save!
      comment = Factory.build(:comment, :project => @project, :user => @user, :target => @project,
        :body => "Hey @#{@mentioned.login}")
      Emailer.should_not_receive(:deliver_notify_comment)
      comment.save!
    end
    
    it "should not notify mentions to @user if he doesn't belong to the project" do
      @mentioned = Factory(:user)
      @mentioned.notify_mentions = true
      @mentioned.save!
      comment = Factory.build(:comment, :project => @project, :user => @user, :target => @project,
        :body => "Hey @#{@mentioned.login}")
      Emailer.should_not_receive(:deliver_notify_comment)
      comment.save!
    end
    
    it "should not notify mentions to the users who posts them" do
      @mentioned = @user
      @mentioned.notify_mentions = true
      @mentioned.save!
      comment = Factory.build(:comment, :project => @project, :user => @user, :target => @project,
        :body => "Hey @#{@mentioned.login}")
      Emailer.should_not_receive(:deliver_notify_comment)
      comment.save!
    end
  end

  #describe "posting to a conversation"
  #describe "posting to a task list"
  #describe "posting to a task"
  
  #describe "marking as read"

  describe "formatting" do
    before do
      @project = Factory(:project)
      @user = @project.user
    end
    
    it "should format text" do
      body = "She *used* to _mean_ so much to ME!"
      comment = Factory.create(:comment, :body => body, :project => @project, :user => @user, :target => @project)
      comment.body_html.should == "<p>She <strong>used</strong> to <em>mean</em> so much to ME!</p>"            
    end
    
    it "should format lists" do
      body = "She used to mean:\n* So\n* much\n* to\n * me!"
      comment = Factory.create(:comment, :body => body, :project => @project, :user => @user, :target => @project)
      comment.body_html.should == "<p>She used to mean:</p>\n<ul>\n\t<li>So</li>\n\t<li>much</li>\n\t<li>to</li>\n\t<li>me!</li>\n</ul>"
    end
    
    it "should format emails and links" do
      body = 'she@couchsurfing.org used to mean so much to www.teambox.com'
      comment = Factory.create(:comment, :body => body, :project => @project, :user => @user, :target => @project)
      comment.body_html.should == "<p><a href=\"mailto:she@couchsurfing.org\">she@couchsurfing.org</a> used to mean so much to <a href=\"http://www.teambox.com\">www.teambox.com</a></p>"
    end
    
    it "should turn to links textile links" do
      body = 'I loved that quote: "I like the Divers, but they want me want to go to a war":http://www.shmoop.com/tender-is-the-night/tommy-barban.html. Great page, too.'
      comment = Factory.create(:comment, :body => body, :project => @project, :user => @user, :target => @project)
      comment.body_html.should == "<p>I loved that quote: <a href=\"http://www.shmoop.com/tender-is-the-night/tommy-barban.html\">I like the Divers, but they want me want to go to a war</a>. Great page, too.</p>"
    end
    
    it "should add http:// in front of links to www.site.com" do
      body = "I'd link my competitors' \"mistakes\":www.failblog.org, but that'd give them free traffic. So instead I link www.google.com."
      comment = Factory.create(:comment, :body => body, :project => @project, :user => @user, :target => @project)
      comment.body_html.should == "<p>I&#8217;d link my competitors&#8217; <a href=\"http://www.failblog.org\">mistakes</a>, but that&#8217;d give them free traffic. So instead I link <a href=\"http://www.google.com\">www.google.com</a>.</p>"
    end

    it "should preserve html links and images" do
      body = 'Did you know the logo from Teambox has <a href="http://en.wikipedia.org/wiki/Color_theory">carefully selected colors</a>? <img src="http://app.teambox.com/images/header_logo_large.jpg"/>'
      comment = Factory.create(:comment, :body => body, :project => @project, :user => @user, :target => @project)
      comment.body_html.should == "<p>Did you know the logo from Teambox has <a href=\"http://en.wikipedia.org/wiki/Color_theory\">carefully selected colors</a>? <img src=\"http://app.teambox.com/images/header_logo_large.jpg\" /></p>"
    end
    
    it "should preserve blocks of code and pre"
  end

  describe "comments mentioning @user" do
    before do
      @project = Factory(:project)
      @user = Factory(:user, :login => 'existing')
    end
    
    it "should link to users page when mentioning @existing if they are in the project" do
      @project.add_user(@user)
      body = "@existing, hey, @existing"
      comment = Factory(:comment, :body => body, :project => @project, :user => @project.user, :target => @project)
      comment.body_html.should == "<p>@<a href=\"/users/existing\">existing</a>, hey, @<a href=\"/users/existing\">existing</a></p>"
      comment.mentioned.should == [@user]
    end
    
    it "should add the mentioned @user to watchers of a Conversation, Task List or Task" do
      @project.add_user(@user)

      %w(conversation task_list task).each do |model|
        element = Factory(model, :project => @project, :user => @project.user)
        element.watchers.should_not include(@user)

        body = "I would like to add @existing to this thread, but not @unexisting."
        comment = Factory(:comment, :body => body, :project => @project, :user => @project.user, :target => element)
        comment.mentioned.should == [@user]
      
        element.reload.watchers.collect(&:id).should == [@project.user, @user].collect(&:id)
      end
    end

    it "should not link to users page when mentioning @existing if they are not in the project" do
      body = "@existing is a cool guy, but he is not in this project"
      comment = Factory.create(:comment, :body => body, :project => @project, :user => @project.user, :target => @project)
      comment.body_html.should == "<p>@existing is a cool guy, but he is not in this project</p>"
      comment.mentioned.should == nil
    end
    
    it "should not link to users page when typing @unexisting" do
      body = "Hey, @unexisting, take a look at this!"
      comment = Factory.create(:comment, :body => body, :project => @project, :user => @project.user, :target => @project)
      comment.body_html.should == "<p>Hey, @unexisting, take a look at this!</p>"
      comment.mentioned.should == nil
    end
  end
end