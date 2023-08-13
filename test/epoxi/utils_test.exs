defmodule Epoxi.UtilsTest do
  use ExUnit.Case, async: true

  alias Epoxi.Test.Helpers
  alias Epoxi.JSONDecoder
  alias Epoxi.Utils

  test "group_by_domain/1 groups emails by their to domains" do
    gmail =
      Helpers.gen_json_payload(3, %{to_domain: "gmail.com"})
      |> JSONDecoder.decode()

    hotmail =
      Helpers.gen_json_payload(2, %{to_domain: "hotmail.com"})
      |> JSONDecoder.decode()

    outlook =
      Helpers.gen_json_payload(1, %{to_domain: "outlook.com"})
      |> JSONDecoder.decode()

    emails = gmail ++ hotmail ++ outlook

    [{"gmail.com", gmails}, {"hotmail.com", hotmails}, {"outlook.com", outlooks}] =
      Utils.group_by_domain(Enum.shuffle(emails))

    assert Enum.count(gmails) == 3
    assert Enum.count(hotmails) == 2
    assert Enum.count(outlooks) == 1
  end

  test "group_by_domain/1 batches by a partition_size" do
    gmail =
      Helpers.gen_json_payload(10, %{to_domain: "gmail.com"})
      |> JSONDecoder.decode()

    hotmail =
      Helpers.gen_json_payload(10, %{to_domain: "hotmail.com"})
      |> JSONDecoder.decode()

    emails = gmail ++ hotmail

    [
      {"gmail.com", gmails_1},
      {"gmail.com", gmails_2},
      {"hotmail.com", hotmails_1},
      {"hotmail.com", hotmails_2}
    ] = Utils.group_by_domain(Enum.shuffle(emails), partition_size: 5)

    assert Enum.count(gmails_1) == 5
    assert Enum.count(gmails_2) == 5
    assert Enum.count(hotmails_1) == 5
    assert Enum.count(hotmails_2) == 5
  end
end
