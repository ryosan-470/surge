defmodule Surge.DML do
  # TODO: `condition_expression` と if が両方指定されているときerror
  def put_item(item, params) do
    model = params[:into]
    if_exp = params[:if] || nil
    opts = params[:opts] || []

    do_put_item(item, into: model, if: if_exp, opts: opts)
  end

  defp do_put_item(item, into: model, if: if_exp, opts: opts) do
    table_name = model.__table_name__

    formated_opts = opts ++ condition_expression(if_exp, model)

    with req <- ExAws.Dynamo.put_item(table_name, Map.from_struct(item), formated_opts),
         {:ok, _} <- ExAws.request(req),
         do: {:ok, item}
  end

  def put_item!(item, params) when is_list(params) do
    model = params[:into]
    if_exp = params[:if] || nil
    opts = params[:opts] || []

    do_put_item!(item, into: model, if: if_exp, opts: opts)
  end

  def do_put_item!(item, into: model, if: if_exp, opts: opts) do
    table_name = model.__table_name__

    formated_opts = opts ++ condition_expression(if_exp, model)

    with req <- ExAws.Dynamo.put_item(table_name, Map.from_struct(item), formated_opts),
         _ <- ExAws.request!(req),
         do: item
  end

  defp condition_expression(nil, _), do: []

  defp condition_expression(exp, _) when is_binary(exp) do
    [condition_expression: exp]
  end

  # TODO: Refactor, parse expression and export
  defp condition_expression([exp | values], model) do
    {cond_exp, attribute_values} =
      Surge.Query.expression_and_values(exp, values, "cond_exp_value")

    attribute_names = Surge.Query.expression_attribute_names(exp, model)

    [
      condition_expression: cond_exp,
      expression_attribute_names: attribute_names,
      expression_attribute_values: attribute_values
    ]
  end

  def get_item(hash: hash, from: model), do: get_item(hash: hash, from: model, opts: [])

  def get_item(hash: hash, from: model, opts: opts) do
    {name, _} = model.__keys__[:hash]
    do_get_item(model, [{name, hash}], opts)
  end

  def get_item(hash: hash, range: range, from: model),
    do: get_item(hash: hash, range: range, from: model, opts: [])

  def get_item(hash: hash, range: range, from: model, opts: opts) do
    {hash_name, _} = model.__keys__[:hash]
    {range_name, _} = get_range_key!(model)

    do_get_item(model, [{hash_name, hash}, {range_name, range}], opts)
  end

  defp do_get_item(model, keys, opts) do
    table_name = model.__table_name__

    with req <- ExAws.Dynamo.get_item(table_name, keys, opts),
         {:ok, result} <- ExAws.request(req),
         decoded <- decode(result, model),
         do: decoded
  end

  defp get_range_key!(model) do
    if model.__keys__[:range] do
      model.__keys__[:range]
    else
      raise Surge.Exceptions.NoDefindedRangeException, "No defined range key in #{model}"
    end
  end

  defp decode(values, _) when values == %{} do
    nil
  end

  defp decode(values, model) when is_map(values) do
    ExAws.Dynamo.decode_item(values, as: model)
  end

  def delete_item(hash: hash, from: model), do: delete_item(hash: hash, from: model, opts: [])

  def delete_item(hash: hash, from: model, opts: opts) do
    {name, _} = model.__keys__[:hash]
    do_delete_item(model, [{name, hash}], opts)
  end

  def delete_item(hash: hash, range: range, from: model),
    do: delete_item(hash: hash, range: range, from: model, opts: [])

  def delete_item(hash: hash, range: range, from: model, opts: opts) do
    {hash_name, _} = model.__keys__[:hash]
    {range_name, _} = get_range_key!(model)

    do_delete_item(model, [{hash_name, hash}, {range_name, range}], opts)
  end

  defp do_delete_item(model, keys, opts) do
    table_name = model.__table_name__

    with req <- ExAws.Dynamo.delete_item(table_name, keys, opts),
         {:ok, result} <- ExAws.request(req),
         do: result
  end
end
