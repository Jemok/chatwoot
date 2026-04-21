# Banking demo (Feature 8): runs Routing::EnforcementService on every new
# conversation. Registered FIRST in AsyncDispatcher.listeners so it gets a
# chance to assign before AutomationRuleListener / NotificationListener etc.
class EnforcedRoutingListener < BaseListener
  def conversation_created(event)
    Routing::EnforcementService.new(event.data[:conversation]).perform
  rescue StandardError => e
    Rails.logger.warn("EnforcedRoutingListener failed: #{e.message}")
  end
end
