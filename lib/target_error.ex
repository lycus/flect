defexception Flect.TargetError, error: "" do
    record_type(error: String.t())

    @spec message(Flect.TargetError.t()) :: String.t()
    def message(ex) do
        ex.error()
    end
end
