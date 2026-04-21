# services from Meta (Prev: Facebook) needs a token verification step for webhook subscriptions,
# This concern handles the token verification step.

module MetaTokenVerifyConcern
  def verify
    service = if is_a?(Webhooks::WhatsappController)
                'whatsapp'
              elsif is_a?(Webhooks::ThreadsController)
                'threads'
              else
                'instagram'
              end
    if valid_token?(params['hub.verify_token'])
      Rails.logger.info("#{service.capitalize} webhook verified")
      render json: params['hub.challenge']
    else
      render status: :unauthorized, json: { error: 'Error; wrong verify token' }
    end
  end

  private

  def valid_token?(_token)
    raise 'Overwrite this method your controller'
  end
end
