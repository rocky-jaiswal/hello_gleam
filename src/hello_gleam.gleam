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
      Error("cannot read / parse file")
    }
  }
}

fn build_requests(city_names: List(String)) {
  let res =
    list.map(city_names, fn(city) {
      request.to("http://localhost:3001/v1/weatherByCity/" <> city)
    })

  case result.all(res) {
    Ok(ok_result) -> Ok(ok_result)
    Error(err) -> {
      io.debug(err)
      Error("cannot build requests")
    }
  }
}

fn make_requests_async(reqs: List(request.Request(String))) {
  let tasks = list.map(reqs, fn(req) { task.async(fn() { hackney.send(req) }) })

  let responses = list.map(tasks, fn(tsk) { task.await_forever(tsk) })

  case result.all(responses) {
    Ok(result) -> Ok(result)
    Error(err) -> {
      io.debug(err)
      Error("cannot make requests")
    }
  }
}

fn parse_responses(responses: List(response.Response(String))) {
  let lst_city_temp =
    list.map(responses, fn(res) { city_temp_from_json(res.body) })

  case result.all(lst_city_temp) {
    Ok(result) -> Ok(result)
    Error(err) -> {
      io.debug(err)
      Error("cannot parse responses")
    }
  }
}

pub fn sort_results(lst_city_temp: List(CityTemp)) {
  let sorted =
    list.sort(lst_city_temp, fn(city1, city2) {
      int.compare(city1.max_temp, city2.max_temp)
    })

  io.println("All cities -")
  io.debug(sorted)

  case list.last(sorted) {
    Ok(c) -> Ok(c.city_name)
    Error(err) -> {
      io.debug(err)
      Error("error in sorting results")
    }
  }
}

pub fn main() {
  io.println("Finding hottest city...")

  // read cities
  // build requests
  // make requests in parallel
  // parse responses into a list of cities and their temparatures
  // get hottest city

  // let cities = result.unwrap(read_cities_from_file("cities.csv"), [])
  // let reqs = result.unwrap(build_requests(cities), [])
  // let responses = result.unwrap(make_requests_async(reqs), [])
  // let cities = result.unwrap(parse_responses(responses), [])
  // let answer = result.unwrap(sort_results(cities), "Error!")

  let answer =
    "cities.csv"
    |> read_cities_from_file
    |> result.map(build_requests)
    |> result.flatten
    |> result.map(make_requests_async)
    |> result.flatten
    |> result.map(parse_responses)
    |> result.flatten
    |> result.map(sort_results)
    |> result.flatten
    |> result.unwrap("Error!")

  io.print("Answer is - " <> answer)
}
