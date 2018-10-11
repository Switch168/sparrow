defmodule SparrowTest do
  use ExUnit.Case, async: false

  import Mock

  alias Helpers.SetupHelper, as: Setup

  @path "/3/device/"
  @cert_path "priv/ssl/client_cert.pem"
  @key_path "priv/ssl/client_key.pem"
  @wrong_cert_path "wrong/priv/ssl/client_cert.pem"
  @wrong_key_path "wrong/priv/ssl/client_key.pem"
  @project_id "OkFCMHandler"

  setup do
    {:ok, _cowboy_pid, cowboys_name} =
      [
        {":_",
         [
           {"/v1/projects/#{@project_id}/messages:send",
            Helpers.CowboyHandlers.OkFCMHandler, []},
           {@path <> "OkResponseHandler",
            Helpers.CowboyHandlers.OkResponseHandler, []}
         ]}
      ]
      |> :cowboy_router.compile()
      |> Setup.start_cowboy_tls(certificate_required: :no)

    on_exit(fn ->
      Application.stop(:sparrow)
      :cowboy.stop_listener(cowboys_name)
    end)

    {:ok, port: :ranch.get_port(cowboys_name)}
  end

  test "Sparrow starts correctly", context do
    # DON'T COPY THIS TOKEN GETTER
    # mock is needed due to bug in Google API:
    # https://firebase.google.com/docs/cloud-messaging/auth-server
    # is in conflict with
    # https://tools.ietf.org/html/rfc7540#section-8.1.2
    # DON'T COPY THIS TOKEN GETTER
    with_mock Sparrow.FCM.V1, [:passthrough],
      get_token_based_authentication: fn ->
        getter = fn ->
          {"authorization", "bearer dummy_token"}
        end

        Sparrow.H2Worker.Authentication.TokenBased.new(getter)
      end do
      config = [
        fcm: [
          [
            path_to_json: "sparrow_token.json",
            endpoint: "localhost",
            port: context[:port],
            tags: [:yippee_ki_yay],
            worker_num: 3
          ]
        ],
        apns: [
          dev: [
            [
              auth_type: :certificate_based,
              cert: @cert_path,
              key: @key_path,
              endpoint: "localhost",
              port: context[:port],
              worker_num: 2,
              tags: [:wololo]
            ],
            [
              auth_type: :certificate_based,
              cert: @cert_path,
              key: @key_path,
              endpoint: "localhost",
              port: context[:port],
              worker_num: 2,
              tags: [:walala]
            ]
          ],
          prod: [
            [
              auth_type: :token_based,
              token_id: :some_atom_id,
              endpoint: "localhost",
              port: context[:port],
              worker_num: 4
            ]
          ],
          tokens: [
            [
              token_id: :some_atom_id,
              key_id: "FAKE_KEY_ID",
              team_id: "FAKE_TEAM_ID",
              p8_file_path: "token.p8"
            ]
          ]
        ]
      ]

      Application.stop(:sparrow)

      Application.put_env(:sparrow, :config, config)
      assert :ok == Application.start(:sparrow)

      assert :ok ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:dev)
               |> Sparrow.APNS.Notification.add_body("dummy body")
               |> Sparrow.API.push()

      assert :ok ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:dev)
               |> Sparrow.APNS.Notification.add_body("dummy body")
               |> Sparrow.API.push([:wololo])

      assert :ok ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:prod)
               |> Sparrow.APNS.Notification.add_title("dummy title")
               |> Sparrow.API.push()

      assert {:error, :configuration_error} ==
               "OkResponseHandler"
               |> Sparrow.APNS.Notification.new(:dev)
               |> Sparrow.APNS.Notification.add_body("dummy body")
               |> Sparrow.API.push([:welele])

      android =
        Sparrow.FCM.V1.Android.new()
        |> Sparrow.FCM.V1.Android.add_title("dummy title")

      notiifcation =
        Sparrow.FCM.V1.Notification.new(:topic, "news", @project_id)
        |> Sparrow.FCM.V1.Notification.add_android(android)

      assert :ok == Sparrow.API.push(notiifcation)
      assert :ok == Sparrow.API.push(notiifcation, [:yippee_ki_yay])

      assert {:error, :configuration_error} ==
               Sparrow.API.push(notiifcation, [
                 :yippee_ki_yay,
                 :wrong_tag
               ])
    end
  end

  test "Sparrow starts correctly, FCM only", context do
    # DON'T COPY THIS TOKEN GETTER
    # mock is needed due to bug in Google API:
    # https://firebase.google.com/docs/cloud-messaging/auth-server
    # is in conflict with
    # https://tools.ietf.org/html/rfc7540#section-8.1.2
    # DON'T COPY THIS TOKEN GETTER
    with_mock Sparrow.FCM.V1, [:passthrough],
      get_token_based_authentication: fn ->
        getter = fn ->
          {"authorization", "bearer dummy_token"}
        end

        Sparrow.H2Worker.Authentication.TokenBased.new(getter)
      end do
      config = [
        fcm: [
          [
            path_to_json: "sparrow_token.json",
            endpoint: "localhost",
            port: context[:port],
            tags: [:yippee_ki_yay],
            worker_num: 3
          ]
        ]
      ]

      Application.stop(:sparrow)

      Application.put_env(:sparrow, :config, config)
      assert :ok == Application.start(:sparrow)

      android =
        Sparrow.FCM.V1.Android.new()
        |> Sparrow.FCM.V1.Android.add_title("dummy title")

      notiifcation =
        Sparrow.FCM.V1.Notification.new(:topic, "news", @project_id)
        |> Sparrow.FCM.V1.Notification.add_android(android)

      assert :ok == Sparrow.API.push(notiifcation)
      assert :ok == Sparrow.API.push(notiifcation, [:yippee_ki_yay])

      assert {:error, :configuration_error} ==
               Sparrow.API.push(notiifcation, [
                 :yippee_ki_yay,
                 :wrong_tag
               ])
    end
  end

  test "Sparrow starts correctly, APNS only", context do
    config = [
      apns: [
        dev: [
          [
            auth_type: :certificate_based,
            cert: @cert_path,
            key: @key_path,
            endpoint: "localhost",
            port: context[:port],
            worker_num: 2,
            tags: [:wololo]
          ],
          [
            auth_type: :certificate_based,
            cert: @cert_path,
            key: @key_path,
            endpoint: "localhost",
            port: context[:port],
            worker_num: 2,
            tags: [:walala]
          ]
        ],
        prod: [
          [
            auth_type: :token_based,
            token_id: :some_atom_id,
            endpoint: "localhost",
            port: context[:port],
            worker_num: 4
          ]
        ],
        tokens: [
          [
            token_id: :some_atom_id,
            key_id: "FAKE_KEY_ID",
            team_id: "FAKE_TEAM_ID",
            p8_file_path: "token.p8"
          ]
        ]
      ]
    ]

    Application.stop(:sparrow)

    Application.put_env(:sparrow, :config, config)
    assert :ok == Application.start(:sparrow)

    assert :ok ==
             "OkResponseHandler"
             |> Sparrow.APNS.Notification.new(:dev)
             |> Sparrow.APNS.Notification.add_body("dummy body")
             |> Sparrow.API.push()

    assert :ok ==
             "OkResponseHandler"
             |> Sparrow.APNS.Notification.new(:dev)
             |> Sparrow.APNS.Notification.add_body("dummy body")
             |> Sparrow.API.push([:wololo])

    assert :ok ==
             "OkResponseHandler"
             |> Sparrow.APNS.Notification.new(:prod)
             |> Sparrow.APNS.Notification.add_title("dummy title")
             |> Sparrow.API.push()

    assert {:error, :configuration_error} ==
             "OkResponseHandler"
             |> Sparrow.APNS.Notification.new(:dev)
             |> Sparrow.APNS.Notification.add_body("dummy body")
             |> Sparrow.API.push([:welele])
  end

  @correct_token [
    token_id: :correct_token_id,
    key_id: "FAKE_KEY_ID",
    team_id: "FAKE_TEAM_ID",
    p8_file_path: "token.p8"
  ]
  test "APNS wrong config" do
    config = [
      apns: [
        dev: [
          [
            auth_type: :certificate_based,
            cert: @wrong_cert_path,
            key: @wrong_key_path
          ]
        ],
        tokens: [
          @correct_token,
          @correct_token
        ]
      ]
    ]
     Application.stop(:sparrow)
    :timer.sleep(1000)
     Application.put_env(:sparrow, :config, config)
    {:error, _} = Application.start(:sparrow)
  end
   test "FCM wrong config" do
    config = [
      fcm: [
        path_to_json: "wrong/sparrow_token.json"
      ]
    ]
     Application.stop(:sparrow)
    :timer.sleep(1000)
     Application.put_env(:sparrow, :config, config)
     {:error, _} = Application.start(:sparrow)
  end
end
