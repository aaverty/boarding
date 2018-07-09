require 'spaceship'
class ApiController < ApplicationController

  skip_before_filter :verify_authenticity_token

  def addTester
    if @message # from a `before_action`
      render json: {message: @message}
      return
    end

    email = params[:email]
    first_name = params[:first_name]
    last_name = params[:last_name]

    if ENV["RESTRICTED_DOMAIN"]
      domains = ENV["RESTRICTED_DOMAIN"].split(",")
      unless domains.include?(email.split("@").last)
        if domains.count == 1
          @message = "Sorry! Early access is currently restricted to people within the #{domains.first} domain."
        else
          @message = "Sorry! Early access is currently restricted to people within the following domains: (#{domains.join(", ")})"
        end
        @type = "error"
        render json: {message: @message, status: @type}
        return
      end
    end

    if boarding_service.itc_token
      if boarding_service.itc_token != params[:token]
        @message = t(:message_invalid_password)
        @type = "error"
        render json: {message: @message, status: @type}
        return
      end
    end

    if email.length == 0
      render json: {message: @message, status: @type}
      return
    end

    if boarding_service.is_demo
      @message = t(:message_demo_page)
      @type = "success"
      render json: {message: @message, status: @type}
      return
    end

    logger.info "Creating a new tester: #{email} - #{first_name} #{last_name}"

    begin
      create_and_add_tester(email, first_name, last_name)
    rescue => ex
      Rails.logger.fatal ex.inspect
      Rails.logger.fatal ex.backtrace.join("\n")

      @message = [t(:message_error), ex.to_s].join(": ")
      @type = "error"
    end

    render json: {message: @message, status: @type}
  rescue => ex
    update_spaceship_message
    raise ex
  end

  private
  def create_and_add_tester(email, first_name, last_name)
    add_tester_response = boarding_service.add_tester(email, first_name, last_name)
    @message = add_tester_response.message
    @type = add_tester_response.type
  end

  def boarding_service
    BOARDING_SERVICE
  end

  def app_metadata
    Rails.cache.fetch('appMetadata', expires_in: 10.minutes) do
      {
          icon_url: boarding_service.app.app_icon_preview_url,
          title: boarding_service.app.name
      }
    end
  end

  def set_app_details
    @metadata = app_metadata
    @title = @metadata[:title]
  end

  def check_disabled_text
    if boarding_service.itc_closed_text
      @message = boarding_service.itc_closed_text
      @type = "warning"
    end
  end

  def check_imprint_url
    if boarding_service.imprint_url
      @imprint_url = boarding_service.imprint_url
    end
  end

end