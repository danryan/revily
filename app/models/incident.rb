class Incident < ActiveRecord::Base
  include Identifiable
  include Trackable
  include Eventable

  attr_accessor :transition_to, :transition_from, :event_action

  serialize :details, JSON

  acts_as_tenant # belongs_to :account

  belongs_to :service, touch: true
  belongs_to :current_user, class_name: 'User', foreign_key: :current_user_id, touch: true
  belongs_to :current_policy_rule, class_name: 'PolicyRule', foreign_key: :current_policy_rule_id, touch: true
  has_many :alerts

  validates :message, presence: true
  validates :service, existence: true

  before_save :ensure_key
  before_create :associate_current_policy_rule
  before_create :associate_current_user
  after_create :trigger
  after_commit :fire_event

  scope :unresolved, -> { where.not(state: 'resolved') } #triggered', 'acknowledged']) }
  scope :triggered, -> { where(state: 'triggered') }
  scope :acknowledged, -> { where(state: 'acknowledged') }
  scope :resolved, -> { where(state: 'resolved') }

  scope :integration, ->(message, key) { key ? unresolved.where(key: key) : unresolved.where(message: message) }

  state_machine initial: :pending do
    state :triggered do
      validate :loop_limit_not_reached
    end
    state :acknowledged
    state :resolved

    event :trigger do
      transition [ :pending, :acknowledged ] => :triggered
    end

    event :acknowledge do
      transition [ :triggered, :acknowledged ] => :acknowledged
    end

    event :escalate do
      transition [ :triggered, :acknowledged ] => :triggered
    end

    event :resolve do
      transition [ :triggered, :acknowledged, :resolved ] => :resolved
    end

    before_transition pending: :triggered, :do => :update_triggered_at
    before_transition triggered: :acknowledged, :do => :update_acknowledged_at
    before_transition triggered: :resolved, :do => [ :update_acknowledged_at, :update_resolved_at ]
    before_transition acknowledged: :resolved, :do => :update_resolved_at
    before_transition on: :escalate, :do => :escalate_to_next_policy_rule

    after_transition any => any do |incident, transition|
      incident.transition_from = transition.from
      incident.transition_to = transition.to
      incident.event_action = transition.event
    end

    after_transition any => :triggered do |incident, transition|
    end

    after_transition :pending => :triggered do |incident, transition|
    end

    after_transition any => :acknowledged do |incident, transition|
    end

    after_transition :on => :resolve do |incident, transition|
    end
  end

  def key_or_uuid
    self.key || self.uuid
  end

  def next_policy_rule
    self.current_policy_rule.try(:lower_item) || policy.try(:policy_rules).try(:first)
  end

  def policy
    service.try(:policy)
  end

  # def account
  #   service.try(:account)
  # end

  protected

  # def loop_limit_reached?
  def loop_limit_not_reached
    if policy && policy.loop_limit <= self.escalation_loop_count
      errors.add(:state, 'cannot escalate when the incident has has reached the escalation loop limit')
    end
  end

  private

  def fire_event
    self.account.events.create(source: self, action: self.event_action, actor: Revily::Event.actor) unless Revily::Event.paused?
    self.service.touch
  end

  def triggered_event
  end

  def acknowledged_event
  end

  def resolved_event
  end

  def ensure_key
    self[:key] ||= SecureRandom.hex
  end

  def update_triggered_at
    write_attribute(:triggered_at, Time.zone.now)
  end

  def update_resolved_at
    write_attribute(:resolved_at, Time.zone.now)
  end

  def update_acknowledged_at
    write_attribute(:acknowledged_at, Time.zone.now)
  end

  def associate_current_policy_rule
    self.current_policy_rule = next_policy_rule
  end

  def associate_current_user
    self.current_user = self.current_policy_rule.try(:current_user)
  end

  def escalate_to_next_policy_rule
    self[:escalation_loop_count] += 1 if next_policy_rule.first?

    associate_current_policy_rule
    associate_current_user
  end

end
