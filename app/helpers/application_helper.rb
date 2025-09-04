module ApplicationHelper
  def qr_code_svg(uri, options = {})
    return "" if uri.blank?

    qr_code = RQRCode::QRCode.new(uri)
    svg = qr_code.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true
    )

    # Return raw SVG for embedding
    svg.html_safe
  end
end
