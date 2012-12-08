defmodule Flect.Target do
    def :get_cc, [], [] do
        System.get_env("FLECT_CC")
    end

    def :get_cc_type, [], [] do
        System.get_env("FLECT_CC_TYPE")
    end

    def :get_os, [], [] do
        System.get_env("FLECT_OS")
    end

    def :get_env, [], [] do
        System.get_env("FLECT_ENV")
    end

    def :get_arch, [], [] do
        System.get_env("FLECT_ARCH")
    end

    def :get_bits, [], [] do
        System.get_env("FLECT_BITS")
    end

    def :get_abi, [], [] do
        System.get_env("FLECT_ABI")
    end
end
