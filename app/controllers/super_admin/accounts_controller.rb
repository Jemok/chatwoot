class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    permitted_params = super
    permitted_params[:limits] = permitted_params[:limits].to_h.compact
    permitted_params[:selected_feature_flags] = params[:enabled_features].keys.map(&:to_sym) if params[:enabled_features].present?
    permitted_params
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def create_facebook_channel
    account = requested_resource
    page_id = params[:page_id]
    page_access_token = params[:page_access_token]
    user_access_token = params[:user_access_token]
    inbox_name = params[:inbox_name]

    ActiveRecord::Base.transaction do
      facebook_channel = account.facebook_pages.create!(
        page_id: page_id,
        user_access_token: user_access_token,
        page_access_token: page_access_token
      )
      facebook_inbox = account.inboxes.create!(
        name: inbox_name,
        channel: facebook_channel,
        queue_kind: 'dm'
      )
      set_instagram_id(page_access_token, facebook_channel)
      set_avatar(facebook_inbox, page_id)
    end
    redirect_back(
      fallback_location: [namespace, account],
      notice: "Facebook channel '#{inbox_name}' created successfully"
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    Rails.logger.error("Error creating Facebook channel: #{e.message}")
    redirect_back(
      fallback_location: [namespace, account],
      alert: "Error creating Facebook channel: #{e.message}"
    )
  end

  def create_instagram_channel
    account = requested_resource
    channel_params = instagram_channel_params

    ActiveRecord::Base.transaction do
      instagram_channel = Channel::Instagram.create!(
        access_token: channel_params[:access_token],
        instagram_id: channel_params[:instagram_id],
        account: account,
        expires_at: parsed_instagram_expires_at(channel_params[:expires_at])
      )

      account.inboxes.create!(
        account: account,
        channel: instagram_channel,
        name: channel_params[:inbox_name],
        queue_kind: 'dm'
      )
    end

    redirect_back(
      fallback_location: [namespace, account],
      notice: "Instagram channel '#{channel_params[:inbox_name]}' created successfully"
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    Rails.logger.error("Error creating Instagram channel: #{e.message}")
    redirect_back(
      fallback_location: [namespace, account],
      alert: "Error creating Instagram channel: #{e.message}"
    )
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  private

  def instagram_channel_params
    params.permit(:instagram_id, :access_token, :inbox_name, :expires_at)
  end

  def parsed_instagram_expires_at(expires_at)
    return 60.days.from_now if expires_at.blank?

    Time.zone.parse(expires_at)
  rescue ArgumentError, TypeError
    60.days.from_now
  end

  def set_instagram_id(page_access_token, facebook_channel)
    fb_object = Koala::Facebook::API.new(page_access_token)
    response = fb_object.get_connections('me', '', { fields: 'instagram_business_account' })
    return if response['instagram_business_account'].blank?

    instagram_id = response['instagram_business_account']['id']
    facebook_channel.update(instagram_id: instagram_id)
  rescue StandardError => e
    Rails.logger.error "Error in set_instagram_id: #{e.message}"
  end

  def set_avatar(facebook_inbox, page_id)
    avatar_url = "https://graph.facebook.com/#{page_id}/picture?type=large"
    Avatar::AvatarFromUrlJob.perform_later(facebook_inbox, avatar_url)
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
