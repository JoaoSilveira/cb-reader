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


hasRun : Stateful err succ -> Bool
hasRun stateful =
    case stateful of
        NotAsked ->
            False

        _ ->
            True


isLoading : Stateful err succ -> Bool
isLoading stateful =
    case stateful of
        Success _ ->
            True

        _ ->
            False


isFinished : Stateful err succ -> Bool
isFinished stateful =
    case stateful of
        Success _ ->
            True

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
