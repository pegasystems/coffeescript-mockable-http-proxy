# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

gulp = require "gulp"
jasmine = require "gulp-jasmine"
istanbul = require "gulp-coffee-istanbul"
cslint = require "gulp-cslint"
codecov = require "gulp-codecov"

require "coffee-register"

gulp.task "test", () ->
  gulp.src(["logic.coffee", "main.coffee"])
    .pipe(istanbul())
    .pipe(istanbul.hookRequire())
    .on("finish", () ->
      gulp.src(["spec/*.coffee"])
        .pipe(jasmine(
          verbose: true,
          includeStackTrace: true
        ))
        .pipe(istanbul.writeReports(
          reporters: ["text", "text-summary", "html"]
        ))
    )

gulp.task "lint", () ->
  opts =
    globals: [
        "beforeEach",
        "console",
        "clearInterval"
        "del",
        "describe",
        "expect",
        "exports",
        "global",
        "it",
        "jasmine",
        "Objects",
        "pending",
        "require",
        "setInterval"
    ]
    rules:
      "strict": "off",
      "global-strict": "off",
      "no-console": "allow"
      "no-return-assignment": "allow"
      "no-shadow": "allow"
      "no-undef": "allow"
      "no-unused-expressions": "allow"

  gulp.src(["*.coffee", "spec/*.coffee"])
    .pipe(cslint(opts))
    .pipe(cslint.format())
    .pipe(cslint.failOnError())
    .pipe(codecov())

gulp.task "default", ["test", "lint"]
