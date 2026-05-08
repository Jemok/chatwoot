# == Schema Information
#
# Table name: installation_configs
#
#  id               :bigint           not null, primary key
#  locked           :boolean          default(TRUE), not null
#  name             :string           not null
#  serialized_value :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_installation_configs_on_name                 (name) UNIQUE
#  index_installation_configs_on_name_and_created_at  (name,created_at) UNIQUE
#
class InstallationConfig < ApplicationRecord
  before_validation :set_lock
  validates :name, presence: true
  validate :saml_sso_users_check, if: -> { name == 'ENABLE_SAML_SSO_LOGIN' }

  # TODO: Get rid of default scope
  # https://stackoverflow.com/a/1834250/939299
  default_scope { order(created_at: :desc) }
  scope :editable, -> { where(locked: false) }

  after_commit :clear_cache

  def value
    serialized_config[:value]
  end

  def value=(value_to_assigned)
    self.serialized_value = {
      value: value_to_assigned
    }
  end

  private

  def serialized_config
    case serialized_value
    when Hash
      serialized_value.with_indifferent_access
    when nil
      {}.with_indifferent_access
    else
      parsed_value = YAML.safe_load(
        serialized_value,
        permitted_classes: [ActiveSupport::HashWithIndifferentAccess, Symbol],
        aliases: true
      )

      parsed_value.is_a?(Hash) ? parsed_value.with_indifferent_access : {}.with_indifferent_access
    end
  rescue Psych::DisallowedClass, Psych::SyntaxError, TypeError
    {}.with_indifferent_access
  end

  def set_lock
    self.locked = true if locked.nil?
    self.serialized_value ||= {}
  end

  def clear_cache
    GlobalConfig.clear_cache
  end

  def saml_sso_users_check
    return unless value == false || value == 'false'
    return unless User.exists?(provider: 'saml')

    errors.add(:base, 'Cannot disable SAML SSO login while users are using SAML authentication')
  end
end
