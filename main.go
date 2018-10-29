package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"strconv"

	"github.com/julienschmidt/httprouter"
	"github.com/pkg/browser"
	"github.com/pkg/errors"
)

var err error

type craigslistRequest struct {
	SearchURL   string `json:"searchURL"`
	ColumnIndex int    `json:"columnIndex"`
}

type craigslistDeleteRequest struct {
	ColumnIndex int `json:"columnIndex"`
}

type craigslistResponse struct {
	ResponseHTML string `json:"response"`
}

type addUrlsResponse struct {
	Urls []string `json:"urls"`
}

func main() {

	loadURLs()

	router := httprouter.New()
	router.ServeFiles("/static/*filepath",
		http.Dir("public"))

	router.POST("/api/", createPostHandler(""))
	router.GET("/api/", createGetHandler(""))
	router.GET("/api/:setIndex", getURLSet)
	router.DELETE("/api/", createDeleteHandler(""))
	router.PUT("/api/", createPutHandler(""))

	browser.OpenURL("http://localhost:8080/static/index.html")
	http.ListenAndServe(":8080", router)
}

func postNoteHandler(w http.ResponseWriter, r *http.Request) {

	var req craigslistRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	req.SearchURL, _ = url.QueryUnescape(req.SearchURL)
	fmt.Printf("POST URL: index is %d\n", req.ColumnIndex)

	var resp craigslistResponse
	resp.ResponseHTML = makeRequest(req.SearchURL)

	//Save the URL
	setURLAt(req.ColumnIndex, req.SearchURL)

	jsonOut, err := json.Marshal(resp)
	fatal(err)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	w.Write(jsonOut)
}

func deleteHandler(w http.ResponseWriter, r *http.Request) {

	var req craigslistDeleteRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	fatal(err)
	fmt.Printf("Delete: the index is %d\n", req.ColumnIndex)

	deleteURLAt(req.ColumnIndex)

	returnURLsJSONResponse(w)
}

func putHandler(w http.ResponseWriter, r *http.Request) {

	addURL()
	returnURLsJSONResponse(w)
}

func getHandler(w http.ResponseWriter, r *http.Request) {

	returnURLsJSONResponse(w)
}

func getURLSet(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	i1, err := strconv.Atoi(ps.ByName("setIndex"))
	fatal(err)
	writeResponseURLSet(w, i1)
}

func writeResponseURLSet(w http.ResponseWriter, setIndex int) {

	log.Printf("writeResponseURLSet(%d)\n", setIndex)
	loadURLSet2()
	returnURLsJSONResponse(w)
}

func makeRequest(url string) string {
	log.Println("makeRequest: " + url)
	resp, err := http.Get(url) //"https://httpbin.org/get"

	//gracefully handle error with invalid craigslist URL
	if err != nil {
		log.Fatalln(err)
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Fatalln(err)
	}

	//log.Println(string(body))
	return string(body)
}

func returnURLsJSONResponse(w http.ResponseWriter) {
	var resp addUrlsResponse
	resp.Urls = getUrls()

	jsonOut, err := json.Marshal(resp)
	fatal(err)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	w.Write(jsonOut)
}

func fatal(err error, msgs ...string) {
	if err != nil {
		var str string
		for _, msg := range msgs {
			str = msg
			break
		}
		panic(errors.Wrap(err, str))
	}
}

func printf(s string, a ...interface{}) {
	fmt.Printf(s, a)
}

func createPostHandler(msg string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
		postNoteHandler(w, r)
	}
}

func createGetHandler(msg string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
		getHandler(w, r)
	}
}

func createDeleteHandler(msg string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
		deleteHandler(w, r)
	}
}

func createPutHandler(msg string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
		putHandler(w, r)
	}
}
