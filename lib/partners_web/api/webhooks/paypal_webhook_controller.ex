defmodule PartnersWeb.Api.Webhooks.PaypalWebhookController do
  @moduledoc """
  Controller for handling PayPal webhook callbacks and subscription events.
  It verifies the webhook signature and processes the event accordingly.
  """

  use PartnersWeb, :controller
  require Logger

  alias Partners.Services.PaypalWebhookVerifier

  def paypal(conn, params) do
    IO.inspect(conn, label: "CONN")
    IO.inspect(params, label: "PARAMS")

    case PaypalWebhookVerifier.validate_webhook_signature(conn) do
      {:ok, result} ->
        Logger.info("✅ PayPal webhook signature VERIFIED: #{inspect(result)}")
        # Function for processing successful webhook
        process_validated_webhook()

        send_resp(
          conn,
          200,
          "Webhook processed successfully."
        )

      {:error, reason} ->
        Logger.error("❌ PayPal webhook signature verification FAILED: #{inspect(reason)}")
        # Function for processing failed webhook
        process_invalid_webhook(reason)

        send_resp(
          conn,
          200,
          "Invalid webhook signature."
        )
    end
  end

  defp process_validated_webhook() do
    # Function for processing validated webhook
    Logger.info("✅ Processing validated PayPal webhook.")
  end

  defp process_invalid_webhook(reason) do
    # Function for processing invalid webhook
    Logger.error("❌ Processing invalid PayPal webhook: #{inspect(reason)}")
  end
end

# Example conn
# CONN: %Plug.Conn{
#   adapter: {Bandit.Adapter, :...},
#   assigns: %{
#     raw_body: "{\"id\":\"WH-4FH7763559456502B-7YC99486266047817\",\"event_version\":\"1.0\",\"create_time\":\"2025-05-13T07:26:54.521Z\",\"resource_type\":\"subscription\",\"resource_version\":\"2.0\",\"event_type\":\"BILLING.SUBSCRIPTION.CREATED\",\"summary\":\"Subscription created\",\"resource\":{\"start_time\":\"2025-05-13T07:26:54Z\",\"quantity\":\"1\",\"create_time\":\"2025-05-13T07:26:54Z\",\"custom_id\":\"28c8a507-423c-4f36-9074-4654b1cd7b19\",\"links\":[{\"href\":\"https://www.sandbox.paypal.com/webapps/billing/subscriptions?ba_token=BA-7J216386D6407125Y\",\"rel\":\"approve\",\"method\":\"GET\"},{\"href\":\"https://api.sandbox.paypal.com/v1/billing/subscriptions/I-SR18H5TSRG6X\",\"rel\":\"edit\",\"method\":\"PATCH\"},{\"href\":\"https://api.sandbox.paypal.com/v1/billing/subscriptions/I-SR18H5TSRG6X\",\"rel\":\"self\",\"method\":\"GET\"}],\"id\":\"I-SR18H5TSRG6X\",\"plan_overridden\":false,\"plan_id\":\"P-1A446093FD195141FNALUJUY\",\"status\":\"APPROVAL_PENDING\"},\"links\":[{\"href\":\"https://api.sandbox.paypal.com/v1/notifications/webhooks-events/WH-4FH7763559456502B-7YC99486266047817\",\"rel\":\"self\",\"method\":\"GET\"},{\"href\":\"https://api.sandbox.paypal.com/v1/notifications/webhooks-events/WH-4FH7763559456502B-7YC99486266047817/resend\",\"rel\":\"resend\",\"method\":\"POST\"}]}"
#   },
#   body_params: %{
#     "create_time" => "2025-05-13T07:26:54.521Z",
#     "event_type" => "BILLING.SUBSCRIPTION.CREATED",
#     "event_version" => "1.0",
#     "id" => "WH-4FH7763559456502B-7YC99486266047817",
#     "links" => [
#       %{
#         "href" => "https://api.sandbox.paypal.com/v1/notifications/webhooks-events/WH-4FH7763559456502B-7YC99486266047817",
#         "method" => "GET",
#         "rel" => "self"
#       },
#       %{
#         "href" => "https://api.sandbox.paypal.com/v1/notifications/webhooks-events/WH-4FH7763559456502B-7YC99486266047817/resend",
#         "method" => "POST",
#         "rel" => "resend"
#       }
#     ],
#     "resource" => %{
#       "create_time" => "2025-05-13T07:26:54Z",
#       "custom_id" => "28c8a507-423c-4f36-9074-4654b1cd7b19",
#       "id" => "I-SR18H5TSRG6X",
#       "links" => [
#         %{
#           "href" => "https://www.sandbox.paypal.com/webapps/billing/subscriptions?ba_token=BA-7J216386D6407125Y",
#           "method" => "GET",
#           "rel" => "approve"
#         },
#         %{
#           "href" => "https://api.sandbox.paypal.com/v1/billing/subscriptions/I-SR18H5TSRG6X",
#           "method" => "PATCH",
#           "rel" => "edit"
#         },
#         %{
#           "href" => "https://api.sandbox.paypal.com/v1/billing/subscriptions/I-SR18H5TSRG6X",
#           "method" => "GET",
#           "rel" => "self"
#         }
#       ],
#       "plan_id" => "P-1A446093FD195141FNALUJUY",
#       "plan_overridden" => false,
#       "quantity" => "1",
#       "start_time" => "2025-05-13T07:26:54Z",
#       "status" => "APPROVAL_PENDING"
#     },
#     "resource_type" => "subscription",
#     "resource_version" => "2.0",
#     "summary" => "Subscription created"
#   },
#   cookies: %{},
#   halted: false,
#   host: "partners-dev-1808.serveo.net",
#   method: "POST",
#   owner: #PID<0.898.0>,
#   params: %{
#     "create_time" => "2025-05-13T07:26:54.521Z",
#     "event_type" => "BILLING.SUBSCRIPTION.CREATED",
#     "event_version" => "1.0",
#     "id" => "WH-4FH7763559456502B-7YC99486266047817",
#     "links" => [
#       %{
#         "href" => "https://api.sandbox.paypal.com/v1/notifications/webhooks-events/WH-4FH7763559456502B-7YC99486266047817",
#         "method" => "GET",
#         "rel" => "self"
#       },
#       %{
#         "href" => "https://api.sandbox.paypal.com/v1/notifications/webhooks-events/WH-4FH7763559456502B-7YC99486266047817/resend",
#         "method" => "POST",
#         "rel" => "resend"
#       }
#     ],
#     "resource" => %{
#       "create_time" => "2025-05-13T07:26:54Z",
#       "custom_id" => "28c8a507-423c-4f36-9074-4654b1cd7b19",
#       "id" => "I-SR18H5TSRG6X",
#       "links" => [
#         %{
#           "href" => "https://www.sandbox.paypal.com/webapps/billing/subscriptions?ba_token=BA-7J216386D6407125Y",
#           "method" => "GET",
#           "rel" => "approve"
#         },
#         %{
#           "href" => "https://api.sandbox.paypal.com/v1/billing/subscriptions/I-SR18H5TSRG6X",
#           "method" => "PATCH",
#           "rel" => "edit"
#         },
#         %{
#           "href" => "https://api.sandbox.paypal.com/v1/billing/subscriptions/I-SR18H5TSRG6X",
#           "method" => "GET",
#           "rel" => "self"
#         }
#       ],
#       "plan_id" => "P-1A446093FD195141FNALUJUY",
#       "plan_overridden" => false,
#       "quantity" => "1",
#       "start_time" => "2025-05-13T07:26:54Z",
#       "status" => "APPROVAL_PENDING"
#     },
#     "resource_type" => "subscription",
#     "resource_version" => "2.0",
#     "summary" => "Subscription created"
#   },
#   path_info: ["api", "webhooks", "paypal"],
#   path_params: %{},
#   port: 80,
#   private: %{
#     :phoenix_view => %{
#       "html" => PartnersWeb.Api.Webhooks.PaypalWebhookHTML,
#       "json" => PartnersWeb.Api.Webhooks.PaypalWebhookJSON
#     },
#     :phoenix_endpoint => PartnersWeb.Endpoint,
#     PartnersWeb.Router => [],
#     :phoenix_action => :paypal,
#     :phoenix_layout => %{},
#     :phoenix_controller => PartnersWeb.Api.Webhooks.PaypalWebhookController,
#     :phoenix_format => "json",
#     :phoenix_router => PartnersWeb.Router,
#     :plug_session_fetch => #Function<1.49469887/1 in Plug.Session.fetch_session/1>,
#     :before_send => [#Function<0.106864063/1 in Plug.Telemetry.call/2>,
#      #Function<1.27030097/1 in Phoenix.LiveReloader.before_send_inject_reloader/3>],
#     :phoenix_request_logger => {"request_logger", "request_logger"}
#   },
#   query_params: %{},
#   query_string: "",
#   remote_ip: {127, 0, 0, 1},
#   req_cookies: %{},
#   req_headers: [
#     {"host", "partners-dev-1808.serveo.net"},
#     {"user-agent", "PayPal/AUHR-214.0-58843836"},
#     {"content-length", "1177"},
#     {"accept", "*/*"},
#     {"cal_poolstack",
#      "amqunphttpretryd:UNPHTTPRETRY*CalThreadId=0*TopLevelTxnStartTime=196c88bdc28*Host=ccg18amqunphttpretryd3"},
#     {"client_pid", "378754"},
#     {"content-type", "application/json"},
#     {"correlation-id", "f438946a28c22"},
#     {"paypal-auth-algo", "SHA256withRSA"},
#     {"paypal-auth-version", "v2"},
#     {"paypal-cert-url",
#      "https://api.sandbox.paypal.com/v1/notifications/certs/CERT-360caa42-fca2a594-90621ecd"},
#     {"paypal-transmission-id", "aac5ed50-2fcb-11f0-a48d-0737b43c836c"},
#     {"paypal-transmission-sig",
#      "HlCp6MHsQGfDdEIGLzRtFqJZxWbEXiukd+uoqxBRwClJaJmKWs0daiDvR0JwDs8yj9FWoAbtQPZSaipiV6y4xMcmA+I3a+T78JM0ivuCKCaVeIznCDfpOirhjhoRcc/YvlkrNo1oaDkRJctxPWfkhb1WZQ0CBqE/j0pK+Uel6szb+7e9EgTmLseRBwIYvv1b8/5O99X2bwPx0JQoIUTkQJZLQvcMvBZBGJinYh5Huv0KLX3lUnSsXwO+BYZcmtB5reP2kMLMkpgOHwRtGffanHS3+ZYQJCWnCvkYDUd3M0AZQN3uS3xnk1qiUApsMLuFkec3s0FdP4eInhKrOyYxow=="},
#     {"paypal-transmission-time", "2025-05-13T07:27:03Z"},
#     {"x-b3-spanid", "f2521f9cb6abf7c4"},
#     {"x-forwarded-for", "173.0.80.117"},
#     {"x-forwarded-host", "partners-dev-1808.serveo.net"},
#     {"x-forwarded-proto", "https"},
#     {"accept-encoding", "gzip"}
#   ],
#   request_path: "/api/webhooks/paypal",
#   resp_body: nil,
#   resp_cookies: %{},
#   resp_headers: [
#     {"cache-control", "max-age=0, private, must-revalidate"},
#     {"x-request-id", "GD8FmECfe8lGEZEAAAFI"}
#   ],
#   scheme: :http,
#   script_name: [],
#   secret_key_base: :...,
#   state: :unset,
#   status: nil
# }

# Example params
# PARAMS: %{
#   "create_time" => "2025-05-13T07:26:54.521Z",
#   "event_type" => "BILLING.SUBSCRIPTION.CREATED",
#   "event_version" => "1.0",
#   "id" => "WH-4FH7763559456502B-7YC99486266047817",
#   "links" => [
#     %{
#       "href" => "https://api.sandbox.paypal.com/v1/notifications/webhooks-events/WH-4FH7763559456502B-7YC99486266047817",
#       "method" => "GET",
#       "rel" => "self"
#     },
#     %{
#       "href" => "https://api.sandbox.paypal.com/v1/notifications/webhooks-events/WH-4FH7763559456502B-7YC99486266047817/resend",
#       "method" => "POST",
#       "rel" => "resend"
#     }
#   ],
#   "resource" => %{
#     "create_time" => "2025-05-13T07:26:54Z",
#     "custom_id" => "28c8a507-423c-4f36-9074-4654b1cd7b19",
#     "id" => "I-SR18H5TSRG6X",
#     "links" => [
#       %{
#         "href" => "https://www.sandbox.paypal.com/webapps/billing/subscriptions?ba_token=BA-7J216386D6407125Y",
#         "method" => "GET",
#         "rel" => "approve"
#       },
#       %{
#         "href" => "https://api.sandbox.paypal.com/v1/billing/subscriptions/I-SR18H5TSRG6X",
#         "method" => "PATCH",
#         "rel" => "edit"
#       },
#       %{
#         "href" => "https://api.sandbox.paypal.com/v1/billing/subscriptions/I-SR18H5TSRG6X",
#         "method" => "GET",
#         "rel" => "self"
#       }
#     ],
#     "plan_id" => "P-1A446093FD195141FNALUJUY",
#     "plan_overridden" => false,
#     "quantity" => "1",
#     "start_time" => "2025-05-13T07:26:54Z",
#     "status" => "APPROVAL_PENDING"
#   },
#   "resource_type" => "subscription",
#   "resource_version" => "2.0",
#   "summary" => "Subscription created"
# }
