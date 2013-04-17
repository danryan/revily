class Account < ActiveRecord::Base
  hound

  attr_accessible :subdomain, :terms_of_service

  has_many :users, dependent: :destroy
  has_many :schedules, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :incidents, through: :services
  has_many :escalation_policies, dependent: :destroy
  has_many :escalation_rules, through: :escalation_policies

  # has_many :assignables, finder_sql: proc { 'SELECT * FROM users.*, }
  
  validates :subdomain, 
    uniqueness: true,
    presence: true,
    allow_blank: false
  validates :terms_of_service,
    acceptance: true

  accepts_nested_attributes_for :users

  def assignables
    (users + schedules)
  end

  def assignables_hash
    assignables.inject({}) do |result, assignable|
      name = assignable.class.name
      (result[name] ||= []) << [assignable.name, assignable.uuid]
      result
    end
  end
end
