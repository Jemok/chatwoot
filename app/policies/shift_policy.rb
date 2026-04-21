class ShiftPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def bulk_create_recurring?
    @account_user.administrator?
  end

  def on_duty?
    true
  end
end
