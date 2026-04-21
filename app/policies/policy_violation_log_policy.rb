class PolicyViolationLogPolicy < ApplicationPolicy
  def index?
    @account_user&.administrator?
  end

  def view?
    index?
  end
end

PolicyViolationLogPolicy.prepend_mod_with('PolicyViolationLogPolicy')
