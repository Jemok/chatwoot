class AutomationRulePolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def clone?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  # Banking demo (Feature 8): explicit predicate for toggling the
  # `enforced` flag on a rule (used by the routing-mode admin page).
  def enforce?
    @account_user.administrator?
  end
end
