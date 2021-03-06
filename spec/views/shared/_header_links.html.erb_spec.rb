require 'rails_helper'

describe 'shared/_header_links.html.erb' do
  let(:permissions) { [] }
  let(:user) { stub_model User, :id => 'test_id', :user_name => 'test_user', :permissions => permissions }

  subject do
    controller.stub :current_user => user
    view.stub :current_user => user
    render :partial => 'shared/header_links'
  end

  describe 'when logged out' do
    let(:user) { nil }
    it { should_not have_content('Welcome') }
    it { should_not have_link('Logout') }
    it { should_not have_link('My Account') }
    it { should_not have_link('System Settings') }
    it { should have_link('Contact & Help', :href => contact_information_path("administrator")) }
  end

  describe 'when logged in' do
    it { should have_content('Logged in as: test_user') }
    it { should have_link('Logout', :href => logout_path) }
    it { should have_link('My Account', :href => user_path(user.id)) }
    it { should have_link('Contact & Help', :href => contact_information_path("administrator")) }
    it { should_not have_link('CHILDREN', :href => children_path)}
    it { should_not have_link('FORMS', :href => form_sections_path)}
    it { should_not have_link('USERS', :href => users_path)}
    it { should_not have_link('SYNC', :href => replications_path)}
  end

end
