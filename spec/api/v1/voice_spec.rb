require 'spec_helper'

describe "voice" do
  pause_events!

  let(:account) { create(:account) }
  let(:user_1) { create(:user, account: account) }
  let(:user_2) { create(:user, account: account) }
  let(:contact_1) { create(:phone_contact, user: user_1, account: account) }
  let(:contact_2) { create(:phone_contact, user: user_2, account: account) }
  let(:policy) { create(:policy, account: account) }
  let(:policy_rule_1) { create(:policy_rule, assignment: user_1, position: 1) }
  let(:policy_rule_2) { create(:policy_rule, assignment: user_2, position: 2) }
  let(:service) { create(:service, policy: policy, account: account) }

  let(:incident) { create(:incident, service: service, account: account) }

  let(:call) { ttt_call('/voice', Revily::Twilio.number, incident.current_user.contacts.first.address) }

  before do
    user_1.contacts << contact_1
    user_2.contacts << contact_2
    policy.policy_rules << policy_rule_1
    policy.policy_rules << policy_rule_2
    service.incidents << incident
  end

  describe 'POST /voice' do
    it 'plays the right message' do
      incident.current_user.should == user_1

      call.should have_say "Revily alert on #{service.name}"
      call.should have_say "#{incident.message}"
      call.within_gather do |gather|
        gather.should have_say "Press 4 to acknowledge, press 6 to resolve, or press 8 to escalate."
        gather.press "anything"
      end
      call.current_path.should == "/voice/receive"
    end

    it 'acknowledge events' do
      call.within_gather do |gather|
        gather.press "4"
      end
      # call.current_path.should == "/voice/receive"
      call.should have_say "All incidents were acknowledged."
      call.should have_say "Goodbye!"
      call.should have_hangup

      incident.reload.should be_acknowledged
    end

    it 'resolve events' do
      call.within_gather do |gather|
        gather.press "6"
      end
      call.should have_say "All incidents were resolved."
      call.should have_say "Goodbye!"
      call.should have_hangup

      incident.reload.should be_resolved
    end

    it 'escalate events' do
      incident.current_user.should == user_1

      call.within_gather do |gather|
        gather.press "8"
      end
      call.should have_say "All incidents were escalated."
      call.should have_say "Goodbye!"
      call.should have_hangup

      incident.reload
      incident.should be_triggered
      incident.current_user.should == user_2
    end

    it 'handle unknown event' do
      call.within_gather do |gather|
        gather.press "0"
      end
      call.should have_say "Your response was invalid."
      call.should have_redirect_to(voice_path)
      call.follow_redirect!
      call.should have_say "Revily alert on #{service.name}"
      call.should have_say "#{incident.message}"
    end
  end

  describe 'POST /voice/receive' do

  end

  describe 'POST /voice/callback' do

  end

  describe 'POST /voice/fallback' do

  end
end
