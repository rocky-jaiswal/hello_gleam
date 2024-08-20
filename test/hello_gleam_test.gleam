import gleeunit
import gleeunit/should

import hello_gleam

pub fn main() {
  gleeunit.main()
}

pub fn hello_world_test() {
  1
  |> should.equal(1)
}

pub fn file_read_test() {
  let cities = hello_gleam.read_cities_from_file("cities.csv")
  cities
  |> should.be_ok
}
