module Stateful exposing (..)


type Stateful err succ
    = NotAsked
    | Loading
    | Success succ
    | Failure err


map : (succA -> succB) -> Stateful err succA -> Stateful err succB
map mapper stateful =
    case stateful of
        Success succ ->
            Success <| mapper succ

        Failure err ->
            Failure err

        Loading ->
            Loading

        NotAsked ->
            NotAsked


mapFailure : (errA -> errB) -> Stateful errA succ -> Stateful errB succ
mapFailure mapper stateful =
    case stateful of
        Success succ ->
            Success succ

        Failure err ->
            Failure <| mapper err

        Loading ->
            Loading

        NotAsked ->
            NotAsked


hasStarted : Stateful err succ -> Bool
hasStarted stateful =
    isNotAsked stateful |> not


hasFinished : Stateful err succ -> Bool
hasFinished stateful =
    case stateful of
        NotAsked ->
            False

        Loading ->
            False

        _ ->
            True


isNotAsked : Stateful err succ -> Bool
isNotAsked stateful =
    case stateful of
        NotAsked ->
            True

        _ ->
            False


isLoading : Stateful err succ -> Bool
isLoading stateful =
    case stateful of
        Loading ->
            True

        _ ->
            False


isSuccess : Stateful err succ -> Bool
isSuccess stateful =
    case stateful of
        Success _ ->
            True

        _ ->
            False


isFailure : Stateful err succ -> Bool
isFailure stateful =
    case stateful of
        Failure _ ->
            True

        _ ->
            False


withDefault : succ -> Stateful err succ -> succ
withDefault default stateful =
    case stateful of
        Success succ ->
            succ

        _ ->
            default


toMaybe : Stateful err succ -> Maybe succ
toMaybe stateful =
    case stateful of
        Success succ ->
            Just succ

        _ ->
            Nothing
