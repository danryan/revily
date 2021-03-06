module BootstrapFlashHelper
  ALERT_TYPES = [:error, :info, :success, :warning]

  def bootstrap_flash
    flash_messages = []
    flash.each do |type, message|
      # Skip empty messages, e.g. for devise messages set to nothing in a locale file.
      next if message.blank?

      type = :success if type == :notice
      type = :danger   if type == :alert
      next unless ALERT_TYPES.include?(type)

      # Array(message).each do |msg|
      #   text = content_tag :div, class: 'row-fluid' do
      #     content_tag :div, class: 'span12' do
      #       content_tag :div, :class => "alert fade in alert-#{type}" do
      #         content_tag(:button, raw("&times;"), :class => "close", "data-dismiss" => "alert") + msg.html_safe
      #       end
      #     end
      #   end
      #   flash_messages << text if message
      # end
      Array(message).each do |msg|
        text = content_tag :div, class: "dialog dialog-#{type} fade in" do
          content_tag(:button, raw("&times;"), :class => "close", "data-dismiss" => "alert") + msg.html_safe
        end
        flash_messages << text if message
      end
    end
    flash_messages.join("\n").html_safe
  end
end
