defmodule Flect.Target do
    @spec get_prefix() :: String.t()
    def :get_prefix, [], [] do
        System.get_env("FLECT_PREFIX")
    end

    @spec get_bin_dir() :: String.t()
    def :get_bin_dir, [], [] do
        System.get_env("FLECT_BIN_DIR")
    end

    @spec get_lib_dir() :: String.t()
    def :get_lib_dir, [], [] do
        System.get_env("FLECT_LIB_DIR")
    end

    @spec get_st_lib_dir() :: String.t()
    def :get_st_lib_dir, [], [] do
        System.get_env("FLECT_ST_LIB_DIR")
    end

    @spec get_sh_lib_dir() :: String.t()
    def :get_sh_lib_dir, [], [] do
        System.get_env("FLECT_SH_LIB_DIR")
    end

    @spec get_cc() :: String.t()
    def :get_cc, [], [] do
        System.get_env("FLECT_CC")
    end

    @spec get_cc_type() :: String.t()
    def :get_cc_type, [], [] do
        System.get_env("FLECT_CC_TYPE")
    end

    @spec get_cc_args() :: String.t()
    def :get_cc_args, [], [] do
        System.get_env("FLECT_CC_ARGS")
    end

    @spec get_ld() :: String.t()
    def :get_ld, [], [] do
        System.get_env("FLECT_LD")
    end

    @spec get_ld_type() :: String.t()
    def :get_ld_type, [], [] do
        System.get_env("FLECT_LD_TYPE")
    end

    @spec get_ld_args() :: String.t()
    def :get_ld_args, [], [] do
        System.get_env("FLECT_LD_ARGS")
    end

    @spec get_os() :: String.t()
    def :get_os, [], [] do
        System.get_env("FLECT_OS")
    end

    @spec get_arch() :: String.t()
    def :get_arch, [], [] do
        System.get_env("FLECT_ARCH")
    end

    @spec get_abi() :: String.t()
    def :get_abi, [], [] do
        System.get_env("FLECT_ABI")
    end

    @spec get_cross() :: String.t()
    def :get_cross, [], [] do
        System.get_env("FLECT_CROSS")
    end
end
