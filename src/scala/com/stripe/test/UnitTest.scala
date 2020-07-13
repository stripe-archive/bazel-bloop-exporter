package com.stripe.test

import com.stripe.thrift
import org.scalatest.FunSuite

class UnitTest extends FunSuite {
  test("I can run") {
    thrift.Musician("Kendrick")
    assert(false)
  }
}
