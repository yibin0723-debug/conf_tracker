import React, { useEffect, useState } from "react"
import { jsonRequest } from "../lib/http"

const EMPTY_FORM = {
  name: "",
  location: "",
  starts_on: "",
  ends_on: "",
  submission_deadline: "",
  rating: "",
  topic_names: "",
  website_url: "",
  description: ""
}

function emptyForm() {
  return { ...EMPTY_FORM }
}

function normalizeConference(conference) {
  return {
    id: conference.id,
    name: conference.name || "",
    location: conference.location || "",
    starts_on: conference.starts_on || "",
    ends_on: conference.ends_on || "",
    submission_deadline: conference.submission_deadline || "",
    rating: conference.rating || "",
    topic_names:
      conference.topic_names ||
      (conference.topics || []).join(", "),
    website_url: conference.website_url || "",
    description: conference.description || ""
  }
}

export default function AdminSpaApp() {
  const [conferences, setConferences] = useState([])
  const [form, setForm] = useState(emptyForm)
  const [editingId, setEditingId] = useState(null)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState("")
  const [notice, setNotice] = useState("")

  const updateField = (field) => (event) => {
    setForm((previous) => ({
      ...previous,
      [field]: event.target.value
    }))
  }

  const resetForm = () => {
    setForm(emptyForm())
    setEditingId(null)
  }

  const loadConferences = async () => {
    setLoading(true)
    setError("")

    try {
      const data = await jsonRequest("/api/admin/conferences")

      setConferences(
        (data.conferences || []).map(normalizeConference)
      )
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadConferences()
  }, [])

  const onSubmit = async (event) => {
    event.preventDefault()

    setSaving(true)
    setError("")
    setNotice("")

    const payload = {
      conference: form
    }

    try {
      if (editingId) {
        await jsonRequest(
          `/api/admin/conferences/${editingId}`,
          {
            method: "PATCH",
            body: JSON.stringify(payload)
          }
        )

        setNotice("Conference updated successfully")
      } else {
        await jsonRequest("/api/admin/conferences", {
          method: "POST",
          body: JSON.stringify(payload)
        })

        setNotice("Conference created successfully")
      }

      resetForm()
      await loadConferences()
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setSaving(false)
    }
  }

  const onEdit = (conference) => {
    setEditingId(conference.id)

    setForm({
      name: conference.name,
      location: conference.location,
      starts_on: conference.starts_on,
      ends_on: conference.ends_on,
      submission_deadline: conference.submission_deadline,
      rating: conference.rating,
      topic_names: conference.topic_names,
      website_url: conference.website_url,
      description: conference.description
    })

    setNotice("")
    setError("")
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  const onDelete = async (conferenceId) => {
    if (!window.confirm("Delete this conference?")) return

    setError("")
    setNotice("")

    try {
      await jsonRequest(
        `/api/admin/conferences/${conferenceId}`,
        { method: "DELETE" }
      )

      setNotice("Conference deleted")

      if (editingId === conferenceId) {
        resetForm()
      }

      await loadConferences()
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  return (
    <div className="grid gap-4 lg:grid-cols-5">
      <div className="panel lg:col-span-2">
        <h2 className="mb-4 text-xl">
          {editingId ? "Edit conference" : "Add conference"}
        </h2>

        <form onSubmit={onSubmit} className="space-y-3">
          <div>
            <label className="text-sm font-medium text-slate-700">
              Name
            </label>

            <input
              className="input"
              value={form.name}
              onChange={updateField("name")}
              required
            />
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Location
            </label>

            <input
              className="input"
              value={form.location}
              onChange={updateField("location")}
              required
            />
          </div>

          <div className="grid gap-2 sm:grid-cols-2">
            <div>
              <label className="text-sm font-medium text-slate-700">
                Starts on
              </label>

              <input
                type="date"
                className="input"
                value={form.starts_on}
                onChange={updateField("starts_on")}
                required
              />
            </div>

            <div>
              <label className="text-sm font-medium text-slate-700">
                Ends on
              </label>

              <input
                type="date"
                className="input"
                value={form.ends_on}
                onChange={updateField("ends_on")}
                required
              />
            </div>
          </div>

          <div className="grid gap-2 sm:grid-cols-2">
            <div>
              <label className="text-sm font-medium text-slate-700">
                Submission deadline
              </label>

              <input
                type="date"
                className="input"
                value={form.submission_deadline}
                onChange={updateField("submission_deadline")}
                required
              />
            </div>

            <div>
              <label className="text-sm font-medium text-slate-700">
                Rating
              </label>

              <input
                className="input"
                value={form.rating}
                onChange={updateField("rating")}
                placeholder="A*, A, B, CORE A..."
              />
            </div>
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Topics
            </label>

            <input
              className="input"
              value={form.topic_names}
              onChange={updateField("topic_names")}
              placeholder="Machine Learning, Computer Vision, NLP"
            />

            <p className="mt-1 text-xs text-slate-500">
              Separate multiple topics with commas.
            </p>
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Website URL
            </label>

            <input
              type="url"
              className="input"
              value={form.website_url}
              onChange={updateField("website_url")}
              placeholder="https://example.org"
            />
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Description
            </label>

            <textarea
              className="input"
              rows={5}
              value={form.description}
              onChange={updateField("description")}
            />
          </div>

          <div className="flex flex-wrap gap-2 pt-2">
            <button
              className="btn-primary"
              type="submit"
              disabled={saving}
            >
              {saving
                ? "Saving..."
                : editingId
                  ? "Save changes"
                  : "Create conference"}
            </button>

            {editingId && (
              <button
                type="button"
                className="btn-ghost"
                onClick={resetForm}
                disabled={saving}
              >
                Cancel edit
              </button>
            )}
          </div>
        </form>

        {notice && (
          <div className="mt-3 rounded-xl border border-emerald-200 bg-mint-100 px-4 py-3 text-emerald-900">
            {notice}
          </div>
        )}

        {error && (
          <div className="mt-3 rounded-xl border border-rosepastel-300 bg-rosepastel-100 px-4 py-3 text-rosepastel-500">
            {error}
          </div>
        )}
      </div>

      <div className="lg:col-span-3">
        <div className="panel">
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2 className="text-xl">
              Conference list
            </h2>

            <button
              type="button"
              className="btn-ghost"
              onClick={loadConferences}
              disabled={loading}
            >
              {loading ? "Refreshing..." : "Refresh"}
            </button>
          </div>

          {!loading && conferences.length === 0 && (
            <p className="text-sm text-slate-500">
              No conferences found.
            </p>
          )}

          <ul className="space-y-3">
            {conferences.map((conference) => (
              <li
                key={conference.id}
                className="rounded-xl border border-emerald-100 bg-white p-4"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <h3 className="text-base font-semibold text-slate-900">
                        {conference.name}
                      </h3>

                      {conference.rating && (
                        <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-900">
                          {conference.rating}
                        </span>
                      )}
                    </div>

                    <p className="mt-1 text-sm text-slate-600">
                      {conference.location}
                    </p>

                    <p className="mt-1 text-sm text-slate-600">
                      Conference: {conference.starts_on} → {conference.ends_on}
                    </p>

                    <p className="mt-1 text-sm font-medium text-rose-700">
                      Submission deadline:{" "}
                      {conference.submission_deadline || "Not set"}
                    </p>

                    {conference.topic_names && (
                      <div className="mt-2 flex flex-wrap gap-1">
                        {conference.topic_names
                          .split(",")
                          .map((topic) => topic.trim())
                          .filter(Boolean)
                          .map((topic) => (
                            <span
                              key={topic}
                              className="rounded-full bg-sky-100 px-2 py-1 text-xs text-sky-800"
                            >
                              {topic}
                            </span>
                          ))}
                      </div>
                    )}

                    {conference.website_url && (
                      <a
                        href={conference.website_url}
                        target="_blank"
                        rel="noreferrer"
                        className="mt-2 inline-block text-sm font-medium text-emerald-700 hover:underline"
                      >
                        Open website
                      </a>
                    )}
                  </div>

                  <div className="flex gap-2">
                    <button
                      type="button"
                      className="btn-ghost"
                      onClick={() => onEdit(conference)}
                    >
                      Edit
                    </button>

                    <button
                      type="button"
                      className="btn-soft"
                      onClick={() => onDelete(conference.id)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  )
}
