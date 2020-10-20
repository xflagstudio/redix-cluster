ESpec.start

ESpec.configure fn(config) ->
  config.before fn ->
    {:shared, count: 1}
  end

  config.finally fn(_shared) ->
    nil
  end
end
