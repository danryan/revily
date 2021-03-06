class V1::VoiceController < V1::ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :set_tenant

  before_action :user

  respond_to :json

  # Example POST:
  #
  # {
  #   "AccountSid" => "ACa2b4e3abff33bdb254d43086255d84e1",
  #   "ToZip" => "48864",
  #   "FromState" => "CA",
  #   "Called" => "+15172145853",
  #   "FromCountry" => "US",
  #   "CallerCountry" => "US",
  #   "CalledZip" => "48864",
  #   "Direction" => "outbound-api",
  #   "FromCity" => "SAN FRANCISCO",
  #   "CalledCountry" => "US",
  #   "CallerState" => "CA",
  #   "CallSid" => "CAa2ca794e2c2bba785d51ba2f9f0796cc",
  #   "CalledState" => "MI",
  #   "From" => "+14157671567",
  #   "CallerZip" => "94108",
  #   "FromZip" => "94108",
  #   "CallStatus" => "in-progress",
  #   "ToCity" => "LANSING",
  #   "ToState" => "MI",
  #   "To" => "+15172145853",
  #   "ToCountry" => "US",
  #   "CallerCity" => "SAN FRANCISCO",
  #   "ApiVersion" => "2010-04-01",
  #   "Caller" => "+14157671567",
  #   "CalledCity" => "LANSING",
  #   "format" => :json,
  #   "controller" => "v1/voice",
  #   "action" => "index"
  # }
  def index
    # user = Contact.includes(:user).find_by(address: params['To']).user
    incident = user.incidents.unresolved.first
    service = incident.try(:service)

    twiml = Twilio::TwiML.build do |res|
      if incident && service
        res.say "Revily alert on #{service.name}:", voice: 'man'
        res.say "#{incident.message}"
        res.gather action: voice_receive_path, method: 'post', num_digits: 1 do |g|
          g.say "Press 4 to acknowledge, press 6 to resolve, or press 8 to escalate."
        end
      else
        res.say "You have no incidents. Goodbye!"
        res.hangup
      end
    end

    render xml: twiml
  end

  # call initiates, twilio POSTs to #respond to get instructions on how to respond
  # respond looks up user, determines the incidents assigned to user
  # and plays incident count, then alert: "message"
  # called chooses an option
  #
  # Example POST:
  #
  # {
  #   "AccountSid" => "ACa2b4e3abff33bdb254d43086255d84e1",
  #   "ToZip" => "48864",
  #   "FromState" => "CA",
  #   "Called" => "+15172145853",
  #   "FromCountry" => "US",
  #   "CallerCountry" => "US",
  #   "CalledZip" => "48864",
  #   "Direction" => "outbound-api",
  #   "FromCity" => "SAN FRANCISCO",
  #   "CalledCountry" => "US",
  #   "CallerState" => "CA",
  #   "CallSid" => "CA54f495d8fc7c4476a946f25f65889e23",
  #   "CalledState" => "MI",
  #   "From" => "+14157671567",
  #   "CallerZip" => "94108",
  #   "FromZip" => "94108",
  #   "CallStatus" => "in-progress",
  #   "ToCity" => "LANSING",
  #   "ToState" => "MI",
  #   "To" => "+15172145853",
  #   "Digits" => "4",
  #   "ToCountry" => "US",
  #   "msg" => "Gather End",
  #   "CallerCity" => "SAN FRANCISCO",
  #   "ApiVersion" => "2010-04-01",
  #   "Caller" => "+14157671567",
  #   "CalledCity" => "LANSING",
  #   "format" => :json,
  #   "action" => "receive",
  #   "controller" => "v1/voice"
  # }
  def receive
    response = voice_params['Digits'].to_i.to_s
    action = Contact::RESPONSE_MAP[response][:action]
    message = Contact::RESPONSE_MAP[response][:message]

    if action
      user.incidents.unresolved.each do |incident|
        incident.send(action)
      end
    end

    twiml = Twilio::TwiML.build do |res|
      res.say message
      if action
        res.say "Goodbye!"
        res.hangup
      else
        res.redirect voice_path
      end
    end

    render xml: twiml
  end

  # TODO(dryan): do something with voice#callback
  def callback
    # logger.info ap params
    head :ok
  end

  # TODO(dryan): do something with voice#fallback
  def fallback
    # logger.info ap params
    head :ok
  end

  protected

  def user
    # @user ||= PhoneContact.includes(:user).where("address LIKE ?", "%#{voice_params['To']}%").first.user
    @user ||= User.joins(:phone_contacts).where("contacts.address LIKE ?", "%#{voice_params['To']}%").first
  end

  def current_actor
    user
  end

  def voice_params
    params.permit(:Digits, :To)
  end

end
