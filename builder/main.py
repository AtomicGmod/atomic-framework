import os
import sys
import hashlib
import argparse
import logging
from gather import gather_autorun, process_includes
from minify import transform_gmod_for_luasrcdiet, minify_lua_luasrcdiet, revert_continue, flatten_to_one_line, minify_lua_basic

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

def log_info(msg):
  logging.info(msg)

def log_error(msg):
  logging.error(msg)

def read_file(path):
  with open(path, "r", encoding="utf-8") as f:
    return f.read()

def write_file(path, content):
  with open(path, "w", encoding="utf-8") as f:
    f.write(content)

def parse_args():
  parser = argparse.ArgumentParser(description="GMod Lua addon builder with LuaSrcDiet")
  parser.add_argument("-p", "--project", required=True, help="Path to project folder")
  parser.add_argument("-o", "--output", required=True, help="Output Lua file path")
  return parser.parse_args()

def main():
  args = parse_args()
  project_path = args.project
  output_file = args.output

  if not os.path.exists(project_path):
    log_error(f"Project path does not exist: {project_path}")
    sys.exit(1)

  log_info("Gathering autorun Lua files...")
  raw_code = gather_autorun(project_path)

  log_info("Processing include blocks...")
  processed_code = process_includes(raw_code, os.path.join(project_path, "lua"))

  log_info("Transforming GMod syntax for LuaSrcDiet...")
  transformed_code = transform_gmod_for_luasrcdiet(processed_code)

  log_info("Minifying Lua code with LuaSrcDiet...")
  minified_code = minify_lua_luasrcdiet(transformed_code)

  log_info("Reverting temporary continue transformations...")
  minified_code = revert_continue(minified_code)

  log_info("Flattening code to a single line...")
  minified_code = flatten_to_one_line(minified_code)

  log_info(f"Writing output to {output_file}...")
  write_file(output_file, minified_code)

  orig_size = len(processed_code.encode("utf-8"))
  min_size = len(minified_code.encode("utf-8"))
  shrink_pct = 100 - (min_size / orig_size * 100) if orig_size > 0 else 0

  sha256 = hashlib.sha256(minified_code.encode("utf-8")).hexdigest()

  log_info(f"Code size reduced by: {shrink_pct:.2f}%")
  log_info(f"SHA256 of minified file: {sha256}")

if __name__ == "__main__":
  main()