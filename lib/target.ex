defmodule Flect.Target do
    def :get_prefix, [], [] do
        System.get_env("FLECT_PREFIX")
    end

    def :get_bin_dir, [], [] do
        System.get_env("FLECT_BIN_DIR")
    end

    def :get_lib_dir, [], [] do
        System.get_env("FLECT_LIB_DIR")
    end

    def :get_st_lib_dir, [], [] do
        System.get_env("FLECT_ST_LIB_DIR")
    end

    def :get_sh_lib_dir, [], [] do
        System.get_env("FLECT_SH_LIB_DIR")
    end

    def :get_cc, [], [] do
        System.get_env("FLECT_CC")
    end

    def :get_cc_type, [], [] do
        System.get_env("FLECT_CC_TYPE")
    end

    def :get_cc_args, [], [] do
        System.get_env("FLECT_CC_ARGS")
    end

    def :get_ld, [], [] do
        System.get_env("FLECT_LD")
    end

    def :get_ld_type, [], [] do
        System.get_env("FLECT_LD_TYPE")
    end

    def :get_ld_args, [], [] do
        System.get_env("FLECT_LD_ARGS")
    end

    def :get_os, [], [] do
        System.get_env("FLECT_OS")
    end

    def :get_arch, [], [] do
        System.get_env("FLECT_ARCH")
    end

    def :get_abi, [], [] do
        System.get_env("FLECT_ABI")
    end

    def :get_cross, [], [] do
        System.get_env("FLECT_CROSS")
    end
end
