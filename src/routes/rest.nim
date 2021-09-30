import json
import jester
import ".."/[types, restutils]

export restutils

template rest*(code: HttpCode; message: string): untyped =
  ## Response of RESTful API
  mixin resp
  resp code, @{"Content-Type": "application/json"}, message

template rest*(code: HttpCode; message: JsonNode): untyped =
  mixin rest
  rest code, $message

template rest*(code: HttpCode; profile: Profile): untyped =
  mixin rest
  rest code, %profile

template rest*(code: HttpCode; timeline: Timeline): untyped =
  mixin rest
  rest code, %timeline

template rest*[T](code: HttpCode; results: Result[T]): untyped =
  mixin rest
  rest code, %results

template rest*[T](code: HttpCode; results: Result[T];
    request: Request): untyped =
  mixin resp
  resp code, @{"Content-Type": "application/json",
               "Link": $getLinkHeader(results, request)}, $ %results

template restError*(code: HttpCode; message: string): untyped =
  mixin rest
  rest code, %newRestApiError(message)
