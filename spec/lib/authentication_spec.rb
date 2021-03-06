require "spec_helper"

class ExampleController < ActionController::Base
  include Authentication
end

describe Authentication, "class" do
  it "adds current_user as a helper method" do
    ExampleController._helper_methods.should include(:current_user)
  end

  it "adds signed_in? as a helper method" do
    ExampleController._helper_methods.should include(:signed_in?)
  end
end

describe Authentication, "#access_denied" do
  subject { ExampleController.new }

  before do
    subject.stubs(:redirect_to)
    subject.stubs(root_url: "/")
  end

  it "redirects to root_url" do
    subject.send(:access_denied)
    subject.should have_received(:redirect_to).with("/")
  end
end

describe Authentication, "#authenticate" do
  subject { ExampleController.new }

  before do
    subject.stubs(:signed_in?)
    subject.stubs(:access_denied)
  end

  describe "when signed in" do
    before do
      subject.stubs(signed_in?: true)
    end

    it "does not call access_denied" do
      subject.authenticate
      subject.should have_received(:access_denied).never
    end
  end

  describe "when not signed in" do
    before do
      subject.stubs(signed_in?: false)
    end

    it "calls access_denied" do
      subject.authenticate
      subject.should have_received(:access_denied)
    end
  end
end

describe Authentication, "#current_user" do
  subject { ExampleController.new }

  before do
    subject.stubs(:user_from_session)
    subject.stubs(:user_from_token)
  end

  describe "when a user is already loaded" do
    before do
      subject.instance_variable_set("@current_user", true)
    end

    it "does not attempt to load a user from the session" do
      subject.current_user
      subject.should have_received(:user_from_session).never
    end
  end

  describe "when no user is loaded" do
    it "attempts to load a user from the session" do
      subject.current_user
      subject.should have_received(:user_from_session)
    end

    it "attempts to load a user via API token" do
      subject.current_user
      subject.should have_received(:user_from_token)
    end

    describe "and a user is found in the session" do
      let(:user) { build_stubbed(:user) }

      before do
        subject.stubs(user_from_session: user)
      end

      it "assigns the user to the instance variable" do
        subject.current_user
        subject.instance_variable_get("@current_user").should == user
      end
    end

    describe "and a user is found via API token" do
      let(:user) { build_stubbed(:user) }

      before do
        subject.stubs(user_from_token: user)
      end

      it "assigns the user to the instance variable" do
        subject.current_user
        subject.instance_variable_get("@current_user").should == user
      end
    end

    describe "and no user is found" do
      it "assigns :false to the instance variable" do
        subject.current_user
        subject.instance_variable_get("@current_user").should == :false
      end
    end
  end
end

describe Authentication, "#current_user=" do
  subject { ExampleController.new }

  let(:session) { {} }

  before do
    subject.stubs(session: session)
  end

  describe "when assigned a user" do
    let(:user) { build_stubbed(:user) }

    before do
      subject.current_user = user
    end

    it "assigns the users ID to session" do
      subject.session[:user].should == user.id
    end

    it "assigns the user to instance variable" do
      subject.instance_variable_get("@current_user").should == user
    end
  end

  describe "when not assigned a user" do
    before do
      subject.current_user = false
    end

    it "assigns nil to session" do
      subject.session[:user].should be_nil
    end

    it "assigns nil to instance variable" do
      subject.instance_variable_get("@current_user").should be_nil
    end
  end
end

describe Authentication, "#signed_in?" do
  subject { ExampleController.new }

  it "returns true when a user is present" do
    subject.stubs(current_user: true)
    subject.should be_signed_in
  end

  it "returns false when no user is present" do
    subject.stubs(current_user: :false)
    subject.should_not be_signed_in
  end
end

describe Authentication, "#user_from_session" do
  subject { ExampleController.new }

  let(:user)    { build_stubbed(:user) }
  let(:session) { {} }

  before do
    subject.stubs(session: session)
    subject.stubs(:current_user=)

    User.stubs(find: user)
  end

  describe "when a user is defined in the session" do
    before do
      session[:user] = 1
    end

    it "attempts to find the user" do
      subject.user_from_session
      User.should have_received(:find).with(session[:user])
    end

    it "assigns the user to current_user" do
      subject.user_from_session
      subject.should have_received(:current_user=).with(user)
    end
  end

  describe "when user is not defined in the session" do
    it "does not attempt to find user" do
      subject.user_from_session
      User.should have_received(:find).never
    end

    it "does not assign current_user" do
      subject.user_from_session
      subject.should have_received(:current_user=).never
    end
  end
end

describe Authentication, "#user_from_token" do
  subject { ExampleController.new }

  let(:user)    { build_stubbed(:user) }
  let(:token)   { "a1b2c3" }
  let(:params)  { {} }
  let(:request) { stub }

  before do
    subject.stubs(params: params)
    subject.stubs(request: request)

    User.stubs(:find_by_public_or_private_token)
    User.stubs(:find_by_private_token)
  end

  describe "when no token is present" do
    it "does not attempt to find a user" do
      subject.user_from_token
      User.should have_received(:find_by_public_or_private_token).never
      User.should have_received(:find_by_private_token).never
    end

    it "returns nil" do
      subject.user_from_token.should be_nil
    end
  end

  describe "when a token is defined in the request parameters for a GET request" do
    before do
      params[:token] = token
      request.stubs(get?: true)

      User.stubs(find_by_public_or_private_token: user)
    end

    it "attempts to find the user by token" do
      subject.user_from_token
      User.should have_received(:find_by_public_or_private_token).with(token).once
      User.should have_received(:find_by_private_token).never
    end

    it "returns the user" do
      subject.user_from_token.should == user
    end
  end

  describe "when a token is defined in the request parameters for a non-GET request" do
    before do
      params[:token] = token
      request.stubs(get?: false)

      User.stubs(find_by_private_token: user)
    end

    it "attempts to find the user by token" do
      subject.user_from_token
      User.should have_received(:find_by_private_token).with(token).once
      User.should have_received(:find_by_public_or_private_token).never
    end

    it "returns the user" do
      subject.user_from_token.should == user
    end
  end
end
