class PolicyViolationLogPolicy < ApplicationPolicy
  def index?
    @account_user&.administrator?
  end

  def create?
    index? || @user.is_a?(AgentBot)
  end

  def view?
    index?
  end
end

PolicyViolationLogPolicy.prepend_mod_with('PolicyViolationLogPolicy')
