module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick,onInput)
import Json.Encode exposing (..)
import Bootstrap.CDN as CDN
import Bootstrap.Grid as Grid
import Bootstrap.Button as Button
import Bootstrap.Form.Input as Input
import Http
import Json.Encode
import Json.Decode exposing (Decoder,string,field)

-- MAIN

main =
  Browser.element { init = init, update = update,
                        subscriptions = subscriptions,
                        view = view }

-- MODEL

type alias Model = { 
    urlResultTuples : (List (String,String)) ,
    debugBreadcrumb : String
    }

init : () -> ( Model, Cmd Msg)
init _ =
    -- The initial model comes from a Request, now it is hard coded
    (Model [("hardUrl1","result1"),("hardUrl2","result2")] "dummy debug"
    , Cmd.none
    )

-- UPDATE

type Msg
  = SearchQueryInput String String
  | LoadButtonPressed String
  | ReceivedQueryResults (Result Http.Error String) String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of

    SearchQueryInput columnId input ->
        ( { model | debugBreadcrumb = input }
        , Cmd.none)

    LoadButtonPressed columnId ->
      (model
      , Http.request
      {
        method = "POST"
      , body = Http.jsonBody <|
              Json.Encode.object [
                   ( "searchURL", Json.Encode.string columnId)
                  ,( "columnIndex", Json.Encode.int 0)
                  ,( "setIndex", Json.Encode.int 0)
                  ]
      , url = "http://localhost:8080/api/"
      , expect = Http.expectJson (\result -> ReceivedQueryResults result columnId) queryDecoder
      , headers = []
      , timeout = Nothing
      , tracker = Nothing
      })

    ReceivedQueryResults result columnId ->
      case result of
        Ok fullText ->
          ({ model | urlResultTuples = 
                updateTuples model.urlResultTuples columnId fullText
          }, Cmd.none)

        Err e ->
            case e of
                Http.BadBody s ->
                    ({ model | urlResultTuples = 
                        updateTuples model.urlResultTuples columnId <| "fail"++s
                     }, Cmd.none)

                Http.BadUrl _     ->  (model,Cmd.none)
                Http.Timeout      ->  (model,Cmd.none)
                Http.NetworkError ->  (model,Cmd.none)
                Http.BadStatus _  ->  (model,Cmd.none)


updateTuples : List (String,String) -> String -> String -> List (String,String)
updateTuples origTuples columnId fullText = 
    let f tuple = 
            if Tuple.first(tuple) == columnId
            then (columnId, fullText)
            else tuple
    in 
    List.map f origTuples


-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

-- VIEW
view : Model -> Html Msg
view model =
  div []
    [
      Grid.container []
        [   CDN.stylesheet
           , text model.debugBreadcrumb
          , Grid.row [] <| List.map queryGridColumnWrap model.urlResultTuples
        ]
    ]


queryGridColumnWrap tuple = Grid.col [] [queryColumn tuple]

queryColumn: (String,String) -> Html Msg
queryColumn urlResultTuple =
    Grid.container []
        [
         Grid.row []
            [ Grid.col []
                [ Input.text [ Input.attrs [ placeholder "URL" ] ] ] 
            ]
        , Grid.row []
            [ Grid.col []
                [ Input.text [ Input.attrs [ placeholder "Search Query", onInput (SearchQueryInput <| Tuple.first(urlResultTuple)) ] ] ]
            ]
        , Grid.row [] [ Grid.col [] [ categorySelector ] ]
        , Grid.row [] [ Grid.col [] [ citySelector ] ]
        , Grid.row []
            [
             Grid.col []
                 [
                   loadRefreshButton  <| Tuple.first(urlResultTuple)
                  ,deleteColumnButton <| Tuple.first(urlResultTuple)
                 ]
            ]
        , Grid.row [] [ Grid.col [] [ 
            queryResults <| Tuple.second(urlResultTuple)
            ]
            ]
        ]

queryResults : String -> Html Msg
queryResults result = postBody result

categorySelector : Html Msg
categorySelector =  select []
                      [ option [] [text "Select Category"]
                      , option [] [text "option 2"]
                      ]

citySelector : Html Msg
citySelector = select [] [
                 option [] [text "Select City"]
                ,option [] [text "Birminham"]
               ]


loadRefreshButton : String -> Html Msg
loadRefreshButton param =
    Button.button
           [ Button.primary
           , Button.small
           , Button.block
           , Button.onClick (LoadButtonPressed param)
           ]
    [ text "Load Results and Save URL" ]


deleteColumnButton : String -> Html Msg
deleteColumnButton param =
    Button.button
        [ Button.danger
        , Button.small
        , Button.block
        , Button.onClick (LoadButtonPressed param)
        ]
    [text "Delete this column"]


-- This rendered-html node is a custom element
-- defined in the html in a <script> tag
-- https://leveljournal.com/server-rendered-html-in-elm

postBody : String -> Html msg
postBody html =
    Html.node "rendered-html"
        [ property "content" (Json.Encode.string html) ]
        []


-- HTTP
queryDecoder : Decoder String
queryDecoder =
  field "response" Json.Decode.string

