import React, { useEffect, useState } from "react"
import { jsonRequest } from "../lib/http"

const INITIAL_FILTERS = {
  q: "",
  location: "",
  topic: "",
  date_from: "",
  date_to: "",
  sort: "deadline_asc"
}

function formatDate(value) {
  if (!value) return "Not set"

  const date = new Date(`${value}T00:00:00`)

  return new Intl.DateTimeFormat("en", {
    year: "numeric",
    month: "short",
    day: "numeric"
  }).format(date)
}

function deadlineText(days) {
  if (days === null || days === undefined) {
    return "Deadline not available"
  }

  if (days < 0) {
    const elapsed = Math.abs(days)

    return `Closed ${elapsed} day${elapsed === 1 ? "" : "s"} ago`
  }

  if (days === 0) {
    return "Deadline is today"
  }

  return `${days} day${days === 1 ? "" : "s"} remaining`
}

function deadlineClasses(days) {
  if (days === null || days === undefined) {
    return "border-slate-200 bg-slate-50 text-slate-700"
  }

  if (days < 0) {
    return "border-slate-200 bg-slate-100 text-slate-600"
  }

  if (days <= 14) {
    return "border-rose-200 bg-rose-50 text-rose-800"
  }

  if (days <= 60) {
    return "border-amber-200 bg-amber-50 text-amber-900"
  }

  return "border-emerald-200 bg-emerald-50 text-emerald-900"
}

export default function ConferenceHubApp() {
  const [filters, setFilters] = useState({
    ...INITIAL_FILTERS
  })

  const [debouncedQuery, setDebouncedQuery] = useState("")
  const [conferences, setConferences] = useState([])
  const [topics, setTopics] = useState([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")

  const updateFilter = (field) => (event) => {
    setFilters((previous) => ({
      ...previous,
      [field]: event.target.value
    }))
  }

  const selectTopic = (topic) => {
    setFilters((previous) => ({
      ...previous,
      topic
    }))
  }

  const resetFilters = () => {
    setFilters({ ...INITIAL_FILTERS })
  }

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setDebouncedQuery(filters.q.trim())
    }, 250)

    return () => window.clearTimeout(timer)
  }, [filters.q])

  useEffect(() => {
    const controller = new AbortController()

    const loadConferences = async () => {
      setLoading(true)
      setError("")

      const query = new URLSearchParams()

      if (debouncedQuery) {
        query.set("q", debouncedQuery)
      }

      if (filters.location.trim()) {
        query.set("location", filters.location.trim())
      }

      if (filters.topic) {
        query.set("topic", filters.topic)
      }

      if (filters.date_from) {
        query.set("date_from", filters.date_from)
      }

      if (filters.date_to) {
        query.set("date_to", filters.date_to)
      }

      query.set("sort", filters.sort)

      try {
        const data = await jsonRequest(
          `/api/conferences?${query.toString()}`,
          { signal: controller.signal }
        )

        setConferences(data.conferences || [])
        setTopics(data.meta?.topics || [])
        setTotal(data.meta?.total || 0)
      } catch (requestError) {
        if (requestError.name !== "AbortError") {
          setError(requestError.message)
        }
      } finally {
        if (!controller.signal.aborted) {
          setLoading(false)
        }
      }
    }

    loadConferences()

    return () => controller.abort()
  }, [
    debouncedQuery,
    filters.location,
    filters.topic,
    filters.date_from,
    filters.date_to,
    filters.sort
  ])

  return (
    <div className="space-y-5">
      <section className="panel">
        <div className="mb-4">
          <h2 className="text-xl font-semibold text-slate-900">
            Find a conference
          </h2>

          <p className="mt-1 text-sm text-slate-600">
            Search by name, description, location or research topic.
          </p>
        </div>

        <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
          <div>
            <label className="text-sm font-medium text-slate-700">
              Search
            </label>

            <input
              type="search"
              className="input"
              value={filters.q}
              onChange={updateFilter("q")}
              placeholder="Conference name or keyword"
            />
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Topic
            </label>

            <select
              className="input"
              value={filters.topic}
              onChange={updateFilter("topic")}
            >
              <option value="">All topics</option>

              {topics.map((topic) => (
                <option key={topic} value={topic}>
                  {topic}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Location
            </label>

            <input
              className="input"
              value={filters.location}
              onChange={updateFilter("location")}
              placeholder="City or country"
            />
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Conference date from
            </label>

            <input
              type="date"
              className="input"
              value={filters.date_from}
              onChange={updateFilter("date_from")}
            />
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Conference date to
            </label>

            <input
              type="date"
              className="input"
              value={filters.date_to}
              onChange={updateFilter("date_to")}
            />
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Sort
            </label>

            <select
              className="input"
              value={filters.sort}
              onChange={updateFilter("sort")}
            >
              <option value="deadline_asc">
                Submission deadline: earliest first
              </option>

              <option value="deadline_desc">
                Submission deadline: latest first
              </option>

              <option value="date_asc">
                Conference date: earliest first
              </option>

              <option value="date_desc">
                Conference date: latest first
              </option>

              <option value="name_asc">
                Conference name
              </option>
            </select>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-slate-600">
            {loading
              ? "Loading conferences..."
              : `${total} conference${total === 1 ? "" : "s"} found`}
          </p>

          <button
            type="button"
            className="btn-ghost"
            onClick={resetFilters}
          >
            Clear filters
          </button>
        </div>
      </section>

      {error && (
        <div className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-rose-800">
          {error}
        </div>
      )}

      {!loading && !error && conferences.length === 0 && (
        <section className="panel text-center">
          <h3 className="font-semibold text-slate-900">
            No matching conferences
          </h3>

          <p className="mt-1 text-sm text-slate-600">
            Change the topic, dates or search keywords.
          </p>
        </section>
      )}

      <div className="grid gap-4 lg:grid-cols-2">
        {conferences.map((conference) => (
          <article
            key={conference.id}
            className="panel flex flex-col"
          >
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <a
                  href={conference.detail_path}
                  className="text-xl font-semibold text-slate-900 hover:text-emerald-700"
                >
                  {conference.name}
                </a>

                <p className="mt-1 text-sm text-slate-600">
                  {conference.location}
                </p>
              </div>

              {conference.rating && (
                <span className="rounded-full bg-amber-100 px-3 py-1 text-sm font-semibold text-amber-900">
                  {conference.rating}
                </span>
              )}
            </div>

            <div className="mt-4 grid gap-3 sm:grid-cols-2">
              <div className="rounded-xl border border-slate-200 bg-slate-50 p-3">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Conference dates
                </p>

                <p className="mt-1 text-sm font-medium text-slate-900">
                  {formatDate(conference.starts_on)}
                  {" — "}
                  {formatDate(conference.ends_on)}
                </p>

                {conference.duration_days && (
                  <p className="mt-1 text-xs text-slate-500">
                    {conference.duration_days} day
                    {conference.duration_days === 1 ? "" : "s"}
                  </p>
                )}
              </div>

              <div
                className={`rounded-xl border p-3 ${deadlineClasses(
                  conference.days_until_submission
                )}`}
              >
                <p className="text-xs font-semibold uppercase tracking-wide">
                  Submission deadline
                </p>

                <p className="mt-1 text-sm font-semibold">
                  {formatDate(conference.submission_deadline)}
                </p>

                <p className="mt-1 text-xs">
                  {deadlineText(
                    conference.days_until_submission
                  )}
                </p>
              </div>
            </div>

            {conference.topics.length > 0 && (
              <div className="mt-4 flex flex-wrap gap-2">
                {conference.topics.map((topic) => (
                  <button
                    key={topic}
                    type="button"
                    onClick={() => selectTopic(topic)}
                    className="rounded-full bg-sky-100 px-3 py-1 text-xs font-medium text-sky-800 hover:bg-sky-200"
                  >
                    {topic}
                  </button>
                ))}
              </div>
            )}

            {conference.description && (
              <p className="mt-4 line-clamp-3 text-sm leading-6 text-slate-600">
                {conference.description}
              </p>
            )}

            <div className="mt-auto flex flex-wrap items-center justify-between gap-3 pt-5">
              <span className="text-xs text-slate-500">
                {conference.bookmark_count} bookmark
                {conference.bookmark_count === 1 ? "" : "s"}
                {conference.bookmarked ? " • Saved by you" : ""}
              </span>

              <div className="flex gap-2">
                <a
                  href={conference.detail_path}
                  className="btn-ghost"
                >
                  Details
                </a>

                {conference.website_url && (
                  <a
                    href={conference.website_url}
                    target="_blank"
                    rel="noreferrer"
                    className="btn-primary"
                  >
                    Website
                  </a>
                )}
              </div>
            </div>
          </article>
        ))}
      </div>
    </div>
  )
}
