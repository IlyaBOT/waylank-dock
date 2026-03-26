//
// Copyright (C) 2015 Rico Tzschichholz
//
// This file is part of Plank.
//
// Plank is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Plank is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Plank {
  /**
   * Creates a new {@link GLib.Settings} object with a given schema and path.
   *
   * It is fatal if no schema to the given schema_id is found!
   *
   * If path is NULL then the path from the schema is used. It is an error if
   * path is NULL and the schema has no path of its own or if path is non-NULL
   * and not equal to the path that the schema does have.
   *
   * @param schema_id a schema ID
   * @param path the path to use
   * @return a new GLib.Settings object
   */
  public static GLib.Settings create_settings (string schema_id, string? path = null) {
    var schema = lookup_settings_schema (schema_id);
    if (schema == null)
      error ("GSettingsSchema '%s' not found", schema_id);

    return new GLib.Settings.full (schema, null, path);
  }

  /**
   * Tries to create a new {@link GLib.Settings} object with a given schema and path.
   *
   * If path is NULL then the path from the schema is used. It is an error if
   * path is NULL and the schema has no path of its own or if path is non-NULL
   * and not equal to the path that the schema does have.
   *
   * @param schema_id a schema ID
   * @param path the path to use
   * @return a new GLib.Settings object or NULL
   */
  public static GLib.Settings ? try_create_settings (string schema_id, string? path = null)
  {
    var schema = lookup_settings_schema (schema_id);
    if (schema == null) {
      warning ("GSettingsSchema '%s' not found", schema_id);
      return null;
    }

    return new GLib.Settings.full (schema, null, path);
  }

  static GLib.SettingsSchema? lookup_settings_schema (string schema_id) {
    unowned GLib.SettingsSchemaSource? default_source = GLib.SettingsSchemaSource.get_default ();
    if (default_source != null) {
      var default_schema = default_source.lookup (schema_id, true);
      if (default_schema != null)
        return default_schema;
    }

    foreach (var schema_dir in get_settings_schema_dirs ()) {
      ensure_compiled_schemas (schema_dir);

      try {
        var source = new GLib.SettingsSchemaSource.from_directory (schema_dir, default_source, false);
        var schema = source.lookup (schema_id, true);
        if (schema != null)
          return schema;
      } catch (Error e) {
        warning ("Unable to load GSettings schemas from '%s': %s", schema_dir, e.message);
      }
    }

    return null;
  }

  static string[] get_settings_schema_dirs () {
    var dirs = new Gee.ArrayList<string> ();

    var current_dir = Environment.get_current_dir ();
    add_settings_schema_dir (dirs, Environment.get_variable ("GSETTINGS_SCHEMA_DIR"));
    add_settings_schema_dir (dirs, Path.build_filename (current_dir, "build", "data"));
    add_settings_schema_dir (dirs, Path.build_filename (current_dir, "data"));
    add_settings_schema_dir (dirs, Path.build_filename (current_dir, "..", "data"));
    add_settings_schema_dir (dirs, Path.build_filename (current_dir, "..", "..", "data"));

    return dirs.to_array ();
  }

  static void add_settings_schema_dir (Gee.ArrayList<string> dirs, string? dir) {
    if (dir == null || dir == "")
      return;
    if (!dirs.contains (dir))
      dirs.add (dir);
  }

  static void ensure_compiled_schemas (string schema_dir) {
    var dir = File.new_for_path (schema_dir);
    if (!dir.query_exists ())
      return;

    var compiled = dir.get_child ("gschemas.compiled");
    if (compiled.query_exists ())
      return;

    if (!contains_uncompiled_schemas (dir))
      return;

    string? compiler = Environment.find_program_in_path ("glib-compile-schemas");
    if (compiler == null) {
      warning ("glib-compile-schemas not found while preparing '%s'", schema_dir);
      return;
    }

    try {
      string? stdout_buf = null;
      string? stderr_buf = null;
      int status = 0;
      Process.spawn_sync (null,
                          { compiler, schema_dir },
                          null,
                          SpawnFlags.SEARCH_PATH,
                          null,
                          out stdout_buf,
                          out stderr_buf,
                          out status);
      if (status != 0) {
        warning ("glib-compile-schemas failed for '%s': %s", schema_dir, (stderr_buf ?? "").strip ());
      }
    } catch (SpawnError e) {
      warning ("Unable to run glib-compile-schemas for '%s': %s", schema_dir, e.message);
    }
  }

  static bool contains_uncompiled_schemas (File dir) {
    try {
      var enumerator = dir.enumerate_children (FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
      FileInfo? info;
      while ((info = enumerator.next_file ()) != null) {
        if (info.get_name ().has_suffix (".gschema.xml"))
          return true;
      }
    } catch (Error e) {
      warning ("Unable to inspect schema directory '%s': %s", dir.get_path () ?? "", e.message);
    }

    return false;
  }

  /**
   * Generates an array containing all combinations of a splitted strings parts
   * while preserving the given order of them.
   *
   * @param s a string
   * @param delimiter a delimiter string
   * @return an array of concated strings
   */
  public static string[] string_split_combine (string s, string delimiter = " ") {
    var parts = s.split (delimiter);
    var count = parts.length;
    var result = new string[count * (count + 1) / 2];

    // Initialize array with the elementary parts
    int pos = 0;
    for (int i = 0; i < count; i++) {
      result[pos] = parts[i];
      pos += (count - i);
    }

    // Recursively filling up the result array
    combine_strings (ref result, delimiter, 0, count);

    return result;
  }

  static void combine_strings (ref string[] result, string delimiter, int n, int i) {
    if (i <= 1)
      return;

    int pos = n;
    for (int j = 0; j < i - 1; j++) {
      pos += (i - j);
      result[n + j + 1] = "%s%s%s".printf (result[n + j], delimiter, result[pos]);
    }

    combine_strings (ref result, delimiter, n + i, i - 1);
  }

  /**
   * Whether the given file looks like a valid .dockitem file
   */
  public inline bool file_is_dockitem (File file) {
    if (file.get_basename ().has_prefix (".goutputstream")) {
      return false;
    }

    try {
      var info = file.query_info (FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_IS_HIDDEN, 0);
      return !info.get_is_hidden () && info.get_name ().has_suffix (".dockitem");
    } catch (Error e) {
      warning (e.message);
    }

    return false;
  }

  public inline double nround (double d, uint n) {
    double result;

    if (n > 0U) {
      var fac = Math.pow (10.0, n);
      result = Math.round (d * fac) / fac;
    } else {
      result = Math.round (d);
    }

    return result;
  }
}
