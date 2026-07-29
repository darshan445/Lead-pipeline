class AgentsController < ApplicationController
  before_action :set_agent, only: [ :show, :edit, :update, :destroy, :discover ]

  def index
    @agents = Agent.order(created_at: :asc)
  end

  def show
    @leads = @agent.leads.order(created_at: :desc)
    @leads = @leads.where(status: params[:status]) if params[:status].present?
    @leads = @leads.where(source: params[:source]) if params[:source].present?
  end

  def new
    @agent = Agent.new
  end

  def create
    @agent = Agent.new(agent_params)

    if @agent.save
      redirect_to agent_path(@agent), notice: "Agent created. Run your first discovery below."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @agent.update(agent_params)
      redirect_to agent_path(@agent), notice: "Agent updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @agent.destroy
    redirect_to agents_path, notice: "Agent deleted. Its leads were kept, unassigned."
  end

  def discover
    query = params[:query].to_s.strip
    platform = params[:platform]
    max_results = (params[:max_results].presence || Leads::DiscoveryJob::MAX_RESULTS).to_i
      .clamp(1, Leads::DiscoveryJob::MAX_RESULTS)

    if query.blank? || !Lead.sources.key?(platform)
      redirect_to agent_path(@agent), alert: "Please provide a query and choose a platform." and return
    end

    Leads::DiscoveryJob.perform_later(query, platform, max_results, @agent.id)

    redirect_to agent_path(@agent), notice: "Discovery started for: #{query} (up to #{max_results} results)"
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(:name, :description, :dm_instructions, :email_instructions)
  end
end
