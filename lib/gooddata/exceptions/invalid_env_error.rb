# encoding: UTF-8
#
# Copyright (c) 2010-2019 GoodData Corporation. All rights reserved.
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

module GoodData
  class InvalidEnvError < RuntimeError
    DEFAULT_MSG = 'Invalid environment: It must be JAVA platform'

    def initialize(msg = DEFAULT_MSG)
      super(msg)
    end
  end
end
