# frozen_string_literal: true

# The seed can be safely called at every boot. Records are located by their
# natural public identifiers and updated, rather than blindly inserted.
module DemoSeeder
  module_function

  CATEGORIES = [
    { name: "Tecnologia", slug: "tecnologia", position: 1 },
    { name: "Casa e decoração", slug: "casa-e-decoracao", position: 2 },
    { name: "Moda", slug: "moda", position: 3 },
    { name: "Esportes", slug: "esportes", position: 4 },
    { name: "Mercado", slug: "mercado", position: 5 },
    { name: "Beleza", slug: "beleza", position: 6 }
  ].freeze

  PRODUCTS = [
    ["tecnologia", "Fone Bluetooth Wave Pro com cancelamento de ruído", "fone-bluetooth-wave-pro", "Som imersivo, até 32 horas de bateria e encaixe confortável para acompanhar toda a sua rotina.", "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=900&q=85", 19_990, 24_990, 20, 28, true, 1],
    ["tecnologia", "Smartwatch Pulse Fit AMOLED 1.8", "smartwatch-pulse-fit", "Monitore treinos, sono e notificações em uma tela vibrante com pulseiras intercambiáveis.", "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=900&q=85", 29_990, 37_490, 20, 18, true, 2],
    ["casa-e-decoracao", "Cafeteira Espresso Casa 15 Bar", "cafeteira-espresso-casa", "Café cremoso em minutos, vaporizador integrado e acabamento premium para sua bancada.", "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=85", 42_990, 52_990, 19, 12, true, 3],
    ["moda", "Tênis Urban Move unissex", "tenis-urban-move", "Leve, versátil e pronto para todos os caminhos. Numeração do 34 ao 44.", "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=85", 18_990, 23_990, 21, 35, true, 4],
    ["casa-e-decoracao", "Luminária Orbital LED sem fio", "luminaria-orbital-led", "Luz quente regulável, design minimalista e autonomia para transformar qualquer ambiente.", "https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=900&q=85", 12_990, 16_990, 24, 22, true, 5],
    ["esportes", "Mochila Trail 28L resistente à água", "mochila-trail-28l", "Compartimentos inteligentes e conforto para a cidade, academia ou próxima aventura.", "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=900&q=85", 15_990, 19_990, 20, 15, false, 6],
    ["mercado", "Kit gourmet: cafés especiais 3x250g", "kit-cafes-especiais", "Seleção de grãos brasileiros torrados recentemente, com notas de chocolate e caramelo.", "https://images.unsplash.com/photo-1447933601403-0c6688de566e?auto=format&fit=crop&w=900&q=85", 8_990, 10_990, 18, 40, false, 7],
    ["beleza", "Sérum facial vitamina C 30ml", "serum-vitamina-c", "Textura leve e antioxidante para uma rotina de cuidado simples e luminosa.", "https://images.unsplash.com/photo-1556228720-195a672e8a03?auto=format&fit=crop&w=900&q=85", 7_490, 9_990, 25, 30, false, 8]
  ].freeze

  def load(db)
    category_ids = {}
    CATEGORIES.each do |category|
      existing = db[:categories].where(slug: category[:slug]).first
      category_ids[category[:slug]] = if existing
                                         db[:categories].where(id: existing[:id]).update(category)
                                         existing[:id]
                                       else
                                         db[:categories].insert(category)
                                       end
    end

    PRODUCTS.each do |category_slug, title, slug, description, image_url, price, original_price, discount, stock, featured, position|
      attributes = {
        category_id: category_ids.fetch(category_slug),
        title: title, slug: slug, description: description, image_url: image_url,
        price_cents: price, original_price_cents: original_price, discount_percent: discount,
        stock: stock, featured: featured, active: true, position: position
      }
      existing = db[:products].where(slug: slug).first
      existing ? db[:products].where(id: existing[:id]).update(attributes) : db[:products].insert(attributes)
    end
  end
end