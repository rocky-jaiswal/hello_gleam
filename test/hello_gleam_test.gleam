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

pub fn sort_test() {
  let hottest_city =
    hello_gleam.sort_results([
      hello_gleam.CityTemp("1", 10, 19),
      hello_gleam.CityTemp("2", 12, 24),
      hello_gleam.CityTemp("3", 13, 22),
    ])

  hottest_city
  |> should.equal("2")
}
