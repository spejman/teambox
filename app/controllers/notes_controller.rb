class NotesController < ApplicationController
  before_filter :load_page
  
  def create
    calculate_position
    
    @note = @page.build_note(params[:note])
    save_slot(@note) if @note.save
    respond_to{|f|f.js}
  end
  
  def edit
    @note = @page.notes.find(params[:id])
    respond_to{|f|f.js}
  end
  
  def update
    @note = @page.notes.find(params[:id])
    @note.update_attributes(params[:note])
    respond_to{|f|f.js}
  end
  
  def destroy
    @note = @page.notes.find(params[:id])
    @slot_id = @note.page_slot.id if @note
    @note.destroy if @note
    respond_to{|f|f.js}    
  end
  
  private
    def load_page
      @page = @current_project.pages.find(params[:page_id])
    end
end