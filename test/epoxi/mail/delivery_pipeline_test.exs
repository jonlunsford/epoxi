defmodule Epoxi.Mail.DeliveryPipelineTest do
  use ExUnit.Case, async: true

  alias Epoxi.Mail.JSONDecoder
  alias Epoxi.Mail.DeliveryPipeline
  alias Epoxi.Test.Helpers

  test "messaging" do
    ref = Broadway.test_message(DeliveryPipeline, 1)
    assert_receive {:ack, ^ref, [%{data: 1}], []}
  end

  test "multiple batch messages" do
    ref = Broadway.test_batch(DeliveryPipeline, [1, 2, 3, 4, 5, 6, 7], batch_mode: :bulk)
    assert_receive {:ack, ^ref, [%{data: 1}], []}, 1000
  end

  test "it handles %Mailman.Email{} data" do
    json = Helpers.gen_json_payload(3)
    emails = JSONDecoder.decode(json)
    ref = Broadway.test_batch(DeliveryPipeline, emails, batch_mode: :bulk)
    assert_receive {:ack, ^ref, [%{data: %Mailman.Email{}}], []}, 1000
  end

  test "it sends emails" do
    json_a = Helpers.gen_json_payload(3)
    json_b = Helpers.gen_json_payload(3)
    ref = Broadway.test_batch(DeliveryPipeline, [json_a, json_b], batch_mode: :bulk)
    assert_receive {:ack, ^ref, [%{data: %Mailman.Email{}}], []}, 1000
  end
end
