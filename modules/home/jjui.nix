{...}: {
  programs.jjui = {
    enable = true;

    settings = {
      # 1) 自定义命令：不再绑定 key，避免覆盖
      custom_commands = {
        "show all commits" = {revset = "all()";};
        "show default view" = {revset = "";};
        "edit immutable" = {
          args = ["edit" "--ignore-immutable" "-r" "$change_id"];
        };
        "squash immutable" = {
          args = ["squash" "--ignore-immutable" "-r" "$change_id"];
        };
        "split immutable" = {
          args = ["split" "--ignore-immutable" "-r" "$change_id"];
        };
      };

      # 2) Leader Key：把增强版操作放到前缀键下
      leader = {
        s = {
          help = "Split (ignore immutable)";
          context = ["$change_id"];
          # 用 shell 执行 jj 命令：按下 "\" 再按 "s" "i"
          send = ["$" "jj split --ignore-immutable -r $change_id" "enter"];
        };
        S = {
          help = "Squash (ignore immutable)";
          context = ["$change_id"];
          send = ["$" "jj squash --ignore-immutable -r $change_id" "enter"];
        };
        e = {
          help = "Edit (ignore immutable)";
          context = ["$change_id"];
          send = ["$" "jj edit --ignore-immutable -r $change_id" "enter"];
        };
      };

      preview = {
        show_at_start = true;
        width_percentage = 60.0;
      };

      oplog = {
        limit = 500;
      };

      graph = {
        batch_size = 100;
      };

      ui = {
        tracer.enabled = true;
      };
    };
  };
}
