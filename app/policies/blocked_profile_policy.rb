class BlockedProfilePolicy < ApplicationPolicy
  def index?
    @account_user&.administrator?
  end

  def create?
    index?
  end

  def destroy?
    index?
  end
end

BlockedProfilePolicy.prepend_mod_with('BlockedProfilePolicy')
