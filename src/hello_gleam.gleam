import gleam/dynamic.{field, int, list, string}
import gleam/hackney
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/otp/task
import gleam/result
import gleam/string
import simplifile

pub type FileParsingError {
  FileParsingError(msg: String)
}

pub type CityTemp {
  CityTemp(city_name: String, min_temp: Int, max_temp: Int)
}

fn city_temp_from_json(
  json_string: String,
) -> Result(CityTemp, json.DecodeError) {
  let decoder =
    dynamic.decode3(
      CityTemp,
      field("cityName", of: string),
      field("maxTemp", of: int),
      field("minTemp", of: int),
    )

  json.decode(from: json_string, using: decoder)
}

pub fn read_cities_from_file(file_name: String) {
  let res = simplifile.read(from: file_name)

  case res {
    Ok(con) -> {
      let cities =
        con
        |> string.split(",")
        |> list.map(string.trim)
      Ok(cities)
    }
    Error(err) -> {
      io.print_error(simplifile.describe_error(err))
      Error(FileParsingError("cannot read / parse file"))
    }
  }
}

fn build_requests(
  city_names: List(String),
) -> Result(List(request.Request(String)), Nil) {
  result.all(
    list.map(city_names, fn(city) {
      request.to("http://localhost:3001/v1/weatherByCity/" <> city)
    }),
  )
}

fn make_requests_async(reqs) {
  let tasks = list.map(reqs, fn(req) { task.async(fn() { hackney.send(req) }) })

  let responses = list.map(tasks, fn(tsk) { task.await_forever(tsk) })

  result.all(responses)
}

fn parse_responses(responses: List(response.Response(String))) {
  let lst_city_temp =
    list.map(responses, fn(res) { city_temp_from_json(res.body) })

  result.all(lst_city_temp)
}

pub fn sort_results(lst_city_temp: List(CityTemp)) {
  let sorted =
    list.sort(lst_city_temp, fn(city1, city2) {
      int.compare(city1.max_temp, city2.max_temp)
    })

  io.println("All cities -")
  io.debug(sorted)

  let city_max_temp = list.last(sorted)

  result.try(city_max_temp, fn(c) { Ok(c.city_name) })
}

pub fn main() {
  io.println("Finding hottest city...")

  // read cities
  // build requests
  // make requests in parallel
  // parse response
  // get hottest city

  let cities = result.unwrap(read_cities_from_file("cities.csv"), [])
  let reqs = result.unwrap(build_requests(cities), [])
  let responses = result.unwrap(make_requests_async(reqs), [])
  let cities = result.unwrap(parse_responses(responses), [])
  let answer = result.unwrap(sort_results(cities), "")

  io.debug("Answer is - " <> answer)
}
