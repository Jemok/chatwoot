class MessagePolicy < ApplicationPolicy
  def create?
    @account_user.present?
  end

  def destroy?
    @account_user&.administrator? || owner?
  end

  # Banking demo: allow the original agent (or admins) to edit their own
  # outgoing replies. Mirrors destroy? so ownership rules stay consistent.
  def edit?
    @account_user&.administrator? || owner?
  end

  def moderate?
    @account_user&.administrator?
  end

  def replace?
    @account_user&.administrator?
  end

  def follow_up?
    @account_user&.administrator? || owner?
  end

  private

  def owner?
    record.respond_to?(:sender_id) && record.sender_id.present? && record.sender_id == @user&.id
  end
end

MessagePolicy.prepend_mod_with('MessagePolicy')
