import gleam/dynamic.{field, int, list, string}
import gleam/hackney
import gleam/http/request
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

type CityTemp {
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
      Error(FileParsingError("fail"))
    }
  }
}

fn make_requests_async(reqs: List(request.Request(String))) {
  let results =
    list.map(reqs, fn(req) { task.async(fn() { hackney.send(req) }) })

  let responses = list.map(results, fn(tsk) { task.await_forever(tsk) })

  let lst_city_temp =
    list.map(result.unwrap(result.all(responses), []), fn(x) {
      city_temp_from_json(x.body)
    })

  let sorted =
    list.sort(result.unwrap(result.all(lst_city_temp), []), fn(city1, city2) {
      int.compare(city1.max_temp, city2.max_temp)
    })

  io.println("All cities -")
  io.debug(sorted)

  let city_max_temp = list.last(sorted)

  let city_name = result.try(city_max_temp, fn(c) { Ok(c.city_name) })

  result.unwrap(city_name, "")
}

pub fn main() {
  io.println("Finding hottest city...")

  let cities = read_cities_from_file("cities.csv")

  let reqs =
    result.try(cities, fn(lst_city) {
      Ok(
        list.map(lst_city, fn(city) {
          request.to("http://localhost:3001/v1/weatherByCity/" <> city)
        }),
      )
    })

  let hottest_city = case reqs {
    Ok(lst_res_req) -> {
      let all_res = result.all(lst_res_req)
      let req = result.unwrap(all_res, [])
      make_requests_async(req)
    }
    Error(err) -> {
      io.debug(err)
      ""
    }
  }

  io.println("Answer is - " <> hottest_city)
}
