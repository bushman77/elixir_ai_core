defmodule Core.Interpreter do
  @moduledoc """
  Interprets parsed sentence structure into meaningful AI responses.
  """

  @doc """
  Takes a parsed sentence structure map and returns an AI response.
  """
  def interpret(%{
        type: :question,
        intent: :can_subject_do_action,
        subject: subject,
        verb: verb
      }) do
    respond_to_capability(subject, verb)
  end

  def interpret(%{type: :statement, subject: subject, verb: verb, object: object}) do
    "#{subject} #{verb}s #{object}. Interesting."
  end

  def interpret(_unknown) do
    "🤖 Hmm... I'm not sure how to respond to that yet."
  end

  # ========== PRIVATE HELPERS ==========

  defp respond_to_capability("you", verb) do
    "🤖 Yes, I can #{verb}!"
  end

  defp respond_to_capability("i", verb) do
    "🤖 Hmm, do you think you can really #{verb}?"
  end

  defp respond_to_capability(_, verb) do
    "🤖 I'm not sure who you're asking to #{verb}, but sounds fun!"
  end
end
