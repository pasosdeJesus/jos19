
module Jos19
  module UnificarHelper

    include Rails.application.routes.url_helpers


    # @param c Sivel2Gen::Caso
    # @param menserror Colchon para mensajes de error
    # @return true y menserror no es modificado o false y se agrega problema a menserror
    def eliminar_caso(c, menserror)
      if !c || !c.id
        menserror << "Caso no válido.\n"
        return false
      end
      begin
        #Sivel2Gen::Caso.connection.execute('BEGIN')
        Sivel2Gen::Caso.connection.execute(
          "DELETE FROM sivel2_sjr_categoria_desplazamiento
           WHERE desplazamiento_id IN (SELECT id FROM sivel2_sjr_desplazamiento
              WHERE caso_id=#{c.id});"
        )
        ['sivel2_sjr_ayudasjr_respuesta', 
         'sivel2_sjr_ayudaestado_respuesta',
         'sivel2_sjr_derecho_respuesta', 
         'sivel2_sjr_aspsicosocial_respuesta', 
         'sivel2_sjr_motivosjr_respuesta', 
         'sivel2_sjr_progestado_respuesta'
        ].each do |trr|
          ord = "DELETE FROM #{trr}
           WHERE respuesta_id IN (SELECT id FROM sivel2_sjr_respuesta 
             WHERE caso_id=#{c.id});"
          #puts "OJO ord='#{ord}'"
          Sivel2Gen::Caso.connection.execute(ord)
        end
        Sivel2Gen::Caso.connection.execute(
          "DELETE FROM sivel2_sjr_accionjuridica_respuesta 
           WHERE respuesta_id IN (SELECT id FROM sivel2_sjr_respuesta 
             WHERE caso_id=#{c.id});"
        )

        Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_sjr_actosjr
        WHERE acto_id IN (SELECT id FROM sivel2_gen_acto
          WHERE caso_id=#{c.id});")

        Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_sjr_desplazamiento
        WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_gen_caso
        SET ubicacion_id=NULL
          WHERE id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET llegada_id=NULL WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET salida_id=NULL WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET llegada_idm=NULL WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET salida_idm=NULL WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("DELETE FROM msip_ubicacion
        WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute(
          "DELETE FROM sivel2_sjr_actividad_casosjr
        WHERE casosjr_id=#{c.id}")
        Sivel2Gen::Caso.connection.execute(
          "DELETE FROM sivel2_sjr_respuesta 
        WHERE caso_id=#{c.id}")
        cs = c.casosjr
        if cs
          cs.destroy
        end
        c.destroy
        return true
      rescue Exception => e
        menserror << "Problema eliminando caso #{e}.\n"
        return false
      end

      #    Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_gen_acto
      #      WHERE caso_id=#{c.id};")
      #    Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_gen_caso
      #      WHERE id=#{c.id};")
      #    Sivel2Gen::Caso.connection.execute('COMMIT;')
    end
    module_function :eliminar_caso


    def consulta_casos_en_blanco
      return Sivel2Gen::Caso.joins(:casosjr).where(
        "contacto_id IN (SELECT id FROM msip_persona "\
        "  WHERE COALESCE(nombres, '')='' "\
        "  AND COALESCE(apellidos, '')='') "\
        "AND COALESCE(memo, '')='' "
      )
    end
    module_function :consulta_casos_en_blanco


    def eliminar_casos_en_blanco
      mens = ""
      pore = UnificarHelper.consulta_casos_en_blanco
      lpore =[]
      pore.each do |ce|
        puts "Eliminando caso en blanco #{ce.id}"
        if eliminar_caso(ce, mens)
          lpore += [ce.id]
        else
          puts "Problema eliminando"
        end
      end
      if lpore.count == 0
        return "No se eliminaron casos en blanco" +
          (mens != '' ? ' (' + mens + ')' : '') + ".\n"
      else
        return "Se eliminaron #{lpore.count} casos en blanco "\
          "(#{lpore.join(', ')})" +
          (mens != '' ? ' ('+mens+')' : '') + ".\n"
      end
    end
    module_function :eliminar_casos_en_blanco


    # Crear un casosjr para el caso c  o lo elimina si no tiene víctimas
    # disponibles para esto.
    # @param caso Sivel2Gen::CAso
    # @parama asesor Usuario que quedará como asesor
    # @param lcom Lista de caso completados
    # @param lelim Lista de casos eliminados
    # @param mens Colchon para mensajes de error
    def arreglar_un_caso_medio_borrado(caso, asesor, lcom, lelim, mens)
      if caso.casosjr
        puts "Este caso no necesita ser arreglado"
        return
      end
      if caso.victima_ids == []
        puts "Caso sin víctimas, es mejor eliminarlo"
        if UnificarHelper.eliminar_caso(caso, mens)
          lelim << caso.id
        end
      else
        vpos = caso.victima_ids.select{
          |vid| 
          idp = Sivel2Gen::Victima.find(vid).persona_id
          Sivel2Gen::Victima.where('caso_id<>?', caso.id).
            where('persona_id<>?', idp).count == 0
        }
        if vpos.count == 0
          puts "Todas las víctimas están en otros casos es mejor eliminarlo"
          if UnificarHelper.eliminar_caso(caso, mens)
            lelim << [caso.id]
          end
        else
          puts "Completando"
          cs = Sivel2Sjr::Casosjr.create(
            caso_id: caso.id,
            contacto_id: vpos[0],
            asesor: us.id,
            oficina: 1 # SIN INFORMACION
          )
          cs.save
          lcom += [caso.id]
        end
      end
    end
    module_function :arreglar_un_caso_medio_borrado

    def consulta_casos_por_arreglar
      Sivel2Gen::Caso.where('id NOT IN (SELECT caso_id FROM sivel2_sjr_casosjr)')
    end
    module_function :consulta_casos_por_arreglar


    def arreglar_casos_medio_borrados
      us = Usuario.habilitados.where(rol: Ability::ROLADMIN).take
      if !us
        return "No hay un administrador para asignarle casos.\n"
      end
      mens = "";
      lcom = [];
      lelim = [];
      pora = consulta_casos_por_arreglar
      numpora = pora.count
      pora.each do |c|
        puts "Arreglando caso medio borrado #{c.id}"
        arreglar_un_caso_medio_borrado(c, us, lcom, lelim, mens)
      end
      if numpora == 0
        mens = "No hay casos parcialmente eliminados.\n"
      else
        mens = "De los #{numpora} casos parcialmente eliminados, se completaron #{lcom.count} (i.e #{lcom.join(', ')}) y se eliminaron #{lelim.count} que no tenían beneficiarios o cuyos beneficiarios estaban en otros casos (i.e #{lelim.join(', ')}).\n";
      end
      return mens
    end
    module_function :arreglar_casos_medio_borrados

    def consulta_personas_en_blanco_por_eliminar
      Msip::Persona.where(
        "(tdocumento_id is null) AND
      (numerodocumento is null OR numerodocumento='') AND
      id NOT IN (SELECT persona_id FROM cor1440_gen_asistencia) AND
      id NOT IN (SELECT persona_id FROM cor1440_gen_caracterizacionpersona) AND
      id NOT IN (SELECT persona_id FROM msip_orgsocial_persona) AND
      id NOT IN (SELECT persona_id FROM sivel2_gen_victima) AND
      (trim(nombres) IN ('','N','NN')) AND
      (trim(apellidos) in ('','N','NN')) AND
      id NOT IN (SELECT  persona1 FROM msip_persona_trelacion) AND
      id NOT IN (SELECT persona2 FROM msip_persona_trelacion) AND
      id NOT IN (SELECT persona_id FROM detallefinanciero_persona) AND
      id NOT IN (SELECT persona_id FROM cor1440_gen_beneficiariopf)"
      )
    end
    module_function :consulta_personas_en_blanco_por_eliminar


    def eliminar_personas_en_blanco
      pore = consulta_personas_en_blanco_por_eliminar
      lpore = []
      pore.each do |p|
        lpore += ["#{p.id} #{p.nombres} #{p.apellidos}"]
        puts "Eliminando beneficiario en blanco #{p.id}"
        p.destroy
      end
      if lpore.count == 0
        mens = "No hay beneficiarios en blanco.\n"
      else
        mens = "Se eliminaron #{lpore.count} beneficiarios en blanco no asociadas a casos ni a actividades (#{lpore.join(', ')}).\n"
      end
      return mens
    end
    module_function :eliminar_personas_en_blanco

    # después de ejecutar este refrescar vista materializada
    # sivel2_gen_conscaso
    def preparar_automaticamente
      mens = arreglar_casos_medio_borrados
      puts mens
      mens2 = eliminar_casos_en_blanco
      puts mens2
      mens += mens2
      mens2 = eliminar_personas_en_blanco
      mens += mens2
      return mens
    end
    module_function :preparar_automaticamente


    def reporte_md_contenido_objeto(en, lista_params, objeto, ind)
      #puts "OJO " + ' '*ind + en.to_s + ' '
      res = ""
      lista_params.each do |atr|
        #puts "OJO   " + ' '*ind + 'atr: \'' + atr.to_s + '\''
        if atr.class == Symbol
          if !objeto[atr].nil?
            alf = objeto.class.asociacion_llave_foranea(atr)
            if alf
              nclase = alf.class_name.constantize
              orel = nclase.find(objeto[atr])
              res << (' '*ind) + '* ' + objeto.class.human_attribute_name(atr) + 
                ': ' + orel.presenta_nombre.to_s + "\n"
            else
              res << (' '*ind) + '* ' + objeto.class.human_attribute_name(atr) + 
                ': ' + objeto[atr].to_s + "\n"
            end
          end
        elsif atr.class == Hash 
          atr.each do |l, v|
            #puts "OJO     " + ' '*ind + 'l: ' + l.to_s
            if v.class != Array
              puts "Se esperaba Array pero en #{l} se encontró #{v.class}\n"
              exit 1
            else
              if l.to_s.end_with?('_attributes')
                nom_nobjeto=l.to_s[0..-12]
                nobjeto = objeto.send(nom_nobjeto)
                # Es colección?
                if nobjeto.class.to_s.end_with?(
                    "ActiveRecord_Associations_CollectionProxy")
                  i = 0
                  nclase2 = nobjeto.class.to_s[0..-44]
                  #puts "OJO     " + ' '*ind + 'nclase2= ' + nclase2
                  clase2 = nclase2.constantize

                  nomh = clase2.human_attribute_name(nom_nobjeto)
                  nobjeto.each do |nobjetoind|
                    res << ' '*ind + "* #{nomh} #{i+1}\n" 
                    res << reporte_md_contenido_objeto(l, v, nobjetoind, ind+2)
                    i += 1
                  end
                elsif nobjeto.class == NilClass
                  res << ' '*ind + "* #{nom_nobjeto} es nil"
                else
                  nomh = nobjeto.class.human_attribute_name(nom_nobjeto)
                  res << ' '*ind + "* #{nomh}\n" 
                  res << reporte_md_contenido_objeto(l, v, nobjeto, ind+2)
                end
              elsif l.to_s.end_with?('_ids')
                nom_nobjeto=l.to_s[0..-4]
                if objeto.respond_to?(l.to_s) 
                  res << ' '*ind + "* #{nom_nobjeto}: " + 
                    "#{objeto.send(l.to_s)}" + "\n" 
                end
              end
            end
          end
        end

      end
      return res
    end
    module_function :reporte_md_contenido_objeto



    # Unificar dos casos, eliminando el de código mayor y dejando
    # su información como etiqueta en el primero
    # @return caso_id donde unifica si lo logra o nil
    def unificar_dos_casos(c1_id, c2_id, current_usuario, menserror)
      tmenserr = ''
      if !c1_id || c1_id.to_i <= 0 ||
          Sivel2Gen::Caso.where(id: c1_id.to_i).count == 0
        tmenserr << "Primera identificación de caso no válida '#{c1_id.to_s}'.\n"
      end
      if !c2_id || c2_id.to_i <= 0 ||
          Sivel2Gen::Caso.where(id: c2_id.to_i).count == 0
        tmenserr << "Segunda identificación de caso no válida '#{c2_id.to_s}'.\n"
      end
      if c1_id.to_i == c2_id.to_i
        tmenserr << "Primera y segunda identificación son iguales, no unificando.\n"
      end

      if tmenserr != ""
        menserror << tmenserr
        return nil
      end

      c1 = Sivel2Gen::Caso.find([c1_id.to_i, c2_id.to_i].min)
      c2 = Sivel2Gen::Caso.find([c1_id.to_i, c2_id.to_i].max)

      eunif = Msip::Etiqueta.where(nombre:'BENEFICIARIOS UNIFICADOS').take
      if !eunif
        tmenserr << "No se encontró etiqueta BENEFICIARIOS UNIFICADOS.\n"
      end

      if tmenserr != ""
        menserror << tmenserr
        return nil
      end

      ep = Sivel2Gen::CasoEtiqueta.new(
        caso_id: c1.id,
        etiqueta_id: eunif.id,
        usuario_id: current_usuario.id,
        fecha: Date.today(),
        observaciones: ""
      )

      Sivel2Sjr::ActividadCasosjr.where(casosjr_id: c2.id).each do |ac|
        ac.casosjr_id = c1.id
        ac.save
        ep.observaciones << "Cambiado caso beneficiario en actividad #{ac.id}\n"
      end

      ep.observaciones = ep.observaciones[0..9999]
      ep.save
      cc = Sivel2Sjr::CasosController.new
      c2rep = UnificarHelper.reporte_md_contenido_objeto("Caso #{c1.id}", cc.lista_params, c1, 0)
      c2id = c2.id
      if eliminar_caso(c2, tmenserr)
        ep.observaciones << "Se unificó y eliminó el registro de caso #{c2id}\n" +
          ep.observaciones << c2rep
      else
        ep.observaciones << "No se logró eliminar el caso #{c2id}, pero si se unficó en el #{c1.id}\n" +
          tmenserr << "No se logró eliminar el caso #{c2id}\n"
      end
      ep.observaciones = ep.observaciones[0..9999]
      begin
        ep.save!
      rescue Exception => e
        puts e.to_s
        debugger
      end


      if tmenserr != ""
        menserror << tmenserr
        return nil
      end

      return c1.id
    end
    module_function :unificar_dos_casos


    # Unificar la información de un segundo beneficario en un primero y elimina el
    # segundo
    # @return [menserr, null] si hay error o ["", persona_id] si no
    def unificar_dos_beneficiarios(p1_id, p2_id, current_usuario)
      menserr = ''
      if !p1_id || p1_id.to_i <= 0 ||
          Msip::Persona.where(id: p1_id.to_i).count == 0
        menserr += "Primera identificación de beneficiario no válida #{p1_id.to_s}.\n"
      end
      if !p2_id || p2_id.to_i <= 0 ||
          Msip::Persona.where(id: p2_id.to_i).count == 0
        menserr += "Segunda identificación de beneficiario no válida #{p2_id.to_s}.\n"
      end
      if p1_id.to_i == p2_id.to_i
        menserr += "Primera y segunda identificación son iguales no unificando.\n"
      end
      if menserr != ""
        return [menserr, nil]
      end

      p1 = Msip::Persona.find([p1_id.to_i, p2_id.to_i].min)
      p2 = Msip::Persona.find([p1_id.to_i, p2_id.to_i].max)

      cp1 = Sivel2Gen::Victima.where(persona_id: p1.id).pluck(:caso_id)
      cp2 = Sivel2Gen::Victima.where(persona_id: p2.id).pluck(:caso_id)
      cc = cp1 & cp2
      if cc.count == 1
        menserr += "El caso #{cc.first} tiene ambos beneficiarios como víctimas; por previción antes debe eliminar alguna de esas víctimas de ese caso.\n"
      elsif cc.count > 1
        menserr += "Los casos #{cc.inspect} tienen a ambos beneficiarios como víctimas; por previción antes en cada uno de esos casos debe eliminar alguna de las dos víctimas.\n"
      end


      ap1 = Cor1440Gen::Asistencia.where(persona_id: p1.id).pluck(&:actividad_id)
      ap2 = Cor1440Gen::Asistencia.where(persona_id: p2.id).pluck(&:actividad_id)
      ac = ap1 & ap2
      if ac.count == 1
        menserr += "La actividad #{ac.first} tiene ambos beneficiarios como asistentes; por previción antes debe eliminar alguno de esos asistentes de esa actividad.\n"
      elsif ac.count > 1
        menserr += "Las actividades #{ac.inspect} tienen a ambos beneficiarios como asistentes; por previción antes en cada una de esas actividades debe eliminar alguno de los dos asistentes.\n"
      end

      eunif = Msip::Etiqueta.where(nombre:'BENEFICIARIOS UNIFICADOS').take
      if !eunif
        menserr += "No se encontró etiqueta BENEFICIARIOS UNIFICADOS.\n"
      end

      if menserr != ""
        return [menserr, nil]
      end

      ep = Msip::EtiquetaPersona.new(
        persona_id: p1.id,
        etiqueta_id: eunif.id,
        usuario_id: current_usuario.id,
        fecha: Date.today(),
        observaciones: ""
      )
      [ :anionac, :mesnac, :dianac,
        :numerodocumento, :tdocumento_id,
        :departamento_id, :municipio_id,
        :clase_id, :nacionalde, :pais_id
      ].each do |c|
        if !p1[c] && p2[c]
          p1[c] = p2[c]
          ep.observaciones << "#{c}->#{p2[c]}\n"
        end
      end
      p1.save
      ep.save

      loop do
        cc1 = Sivel2Sjr::Casosjr.where(contacto_id: p1.id).pluck(:caso_id)
        cc2 = Sivel2Sjr::Casosjr.where(contacto_id: p2.id).pluck(:caso_id)
        if cc1.count > 0 and cc2.count > 0
          cr = unificar_dos_casos(cc1[0], cc2[0], current_usuario, menserr)
          if !cr.nil?
            ep.observaciones << "Unificados casos #{cc1[0]} y #{cc2[0]} en #{cr}\n"
          else
            menserr << "Primer beneficiario (#{p1.id} #{p1.nombres.to_s} #{p1.apellidos.to_s}) es contacto en caso #{cc1[0]} y segundo beneficiario (#{p2.id} #{p2.nombres} #{p2.apellidos}) es contacto en caso #{cc2[0]}. Se intentó sin éxito la unificación de los dos casos.\n"
            return [menserr, nil]
          end
        end
        break if cc1.count == 0 || cc2.count == 0;
      end

      cp2.each do |cid|
        Sivel2Gen::Victima.where(
          caso_id: cid, persona_id: p2.id
        ).each do |vic|
          if Sivel2Gen::Victima.where(caso_id: cid, persona_id: p1.id).count == 0
            nv = vic.dup
            nv.persona_id = p1.id
            nv.save
            nvs = vic.victimasjr.dup
            if nvs
              nvs.victima_id = nv.id
              nvs.save
            end
            ep.observaciones << "Creada víctma en caso #{cid}\n"
          end
          ep.save
          csjr = vic.caso.casosjr
          if csjr.contacto_id == p2.id
            Sivel2Sjr::Casosjr.connection.execute <<-SQL
            UPDATE sivel2_sjr_casosjr SET
              contacto_id=#{p1.id}
              WHERE contacto_id=#{p2.id}
            SQL
            #          csjr.contacto_id = p1.id
            #          if !csjr.save
            #            puts csjr.errors
            #            debugger
            #          end
            ep.observaciones << "Cambiado contacto en caso #{cid}\n"
          end
          ep.save
          Sivel2Gen::Acto.where(caso_id: cid, persona_id: p1.id).each do |ac|
            ac.persona_id = p1.id
            ac.save!
            ep.observaciones << "Cambiado acto en caso #{cid}\n"
          end
          ep.save
          ep.observaciones << "Elimina beneficiario #{vic.persona_id} del caso #{cid}\n"
          vic.destroy
          ep.observaciones = ep.observaciones[0..4998]
          ep.save
        end
      end

      Cor1440Gen::Caracterizacionpersona.where(persona_id: p2.id).each do |cp|
        cp.persona_id = p1.id
        cp.save
        ep.observaciones << "Cambiada caracterizacíon #{cp.id}\n"
      end
      Msip::PersonaTrelacion.where(persona1: p2.id).each do |pt|
        pt.persona1 = p1.id
        pt.save
        ep.observaciones << "Cambiada relacion con beneficiario #{pt.persona2}\n"
      end
      Msip::PersonaTrelacion.where(persona2: p2.id).each do |pt|
        pt.persona2 = p1.id
        pt.save
        ep.observaciones << "Cambiada relacion con beneficiario #{pt.persona1}\n"
      end

      #msip_datosbio no debe estar lleno
      Msip::OrgsocialPersona.where(persona_id: p2.id).each do |op|
        op.persona_id = p1.id
        op.save
        ep.observaciones << "Cambiada organización social #{op.orgsocial_id}\n"
      end

      #mr519_gen_encuestapersona no debería estar llena
      Msip::EtiquetaPersona.where(persona_id: p2.id).each do |ep2|
        ep2.persona_id = p1.id
        ep2.save
        ep.observaciones << "Cambiada etiqueta #{ep.etiqueta.nombre}\n"
      end

      # cor1440_gen_beneficiariopf no tiene id
      lpf = Cor1440Gen::Beneficiariopf.where(persona_id: p2.id).
        pluck(:proyectofinanciero_id)
      lpf.each do |pfid|
        if Cor1440Gen::Beneficiariopf.where(persona_id: p1.id, 
            proyectofinanciero_id: pfid).count == 0
          Cor1440Gen::Beneficiariopf.connection.execute <<-SQL
          INSERT INTO cor1440_gen_beneficiariopf 
            (persona_id, proyectofinanciero_id) 
            VALUES (#{p1.id}, #{pfid});
          SQL
          ep.observaciones << "Cambiado beneficiario en convenio financiado #{pfid}\n"
        end
        Cor1440Gen::Beneficiariopf.connection.execute <<-SQL
        DELETE FROM cor1440_gen_beneficiariopf WHERE 
          persona_id=#{p2.id} AND
          proyectofinanciero_id=#{pfid};
        SQL
      end
      ::Detallefinanciero.joins(:persona).where(
        'msip_persona.id' => p2.id
      ).each do |bp|
        bp.persona_id = p1.id
        bp.save
        ep.observaciones << "Cambiado detalle financiero #{bp.detallefinanciero_id}\n"
      end
      #detallefinanciero_persona

      ep.observaciones = ep.observaciones[0..4998]
      ep.save
      p2.destroy
      ep.observaciones << "Se unificó y eliminó el registro de beneficiario #{p2.id}\n"\
        "* Nombres: #{p2.nombres.to_s}\n"\
        "* Apellidos: #{p2.apellidos.to_s}\n"\
        "* Tipo doc.: #{p2.tdocumento_id ? p2.tdocumento.sigla : ''}\n"\
        "* Número de doc.: #{p2.numerodocumento.to_s}\n"\
        "* Año nac.: #{p2.anionac.to_s}\n"\
        "* Mes nac.: #{p2.mesnac.to_s}\n"\
        "* Dia nac.: #{p2.dianac.to_s}\n"\
        "* Sexo nac.: #{p2.sexo.to_s}\n"\
        "* Pais nac.: #{p2.pais_id ? p2.pais.nombre : ''}\n"\
        "* Departamento nac.: #{p2.departamento_id ? p2.departamento.nombre : ''}\n"\
        "* Muncipio nac.: #{p2.municipio_id ? p2.municipio.nombre : ''}\n"\
        "* Centro poblado nac.: #{p2.clase_id ? p2.clase.nombre : ''}\n"\
        "* Nacional de: #{p2.nacionalde ? p2.nacional.nombre : ''}\n"\
        "* Fecha creación: #{p2.created_at.to_s}\n"\
        "* Fecha actualización: #{p2.updated_at.to_s}.\n"

      ep.observaciones = ep.observaciones[0..4998]
      ep.save

      return ["", p1.id]
    end
    module_function :unificar_dos_beneficiarios

    def consulta_duplicados_autom
      # La siguiente vista haría breve la siguiente consulta pero
      # su refresco toma como 15 min.
      #    Msip::Persona.connection.execute <<-SQL
      #       DROP MATERIALIZED VIEW IF EXISTS duplicados_rep;
      #       CREATE MATERIALIZED VIEW duplicados_rep AS (
      #         SELECT sub.sigla,
      #         sub.numerodocumento,
      #         sub.rep,
      #         p1.id AS id1,
      #         p2.id AS id2,
      #         p1.nombres AS nombres1,
      #         p1.apellidos AS apellidos1,
      #         p2.nombres AS nombres2,
      #         p2.apellidos AS apellidos2,
      #         soundexespm(p1.nombres) AS sn1,
      #         soundexespm(p1.apellidos) AS sa1,
      #         soundexespm(p2.nombres) AS sn2,
      #         soundexespm(p2.apellidos) AS sa2
      #         FROM (SELECT t.sigla,
      #           p.tdocumento_id,
      #           p.numerodocumento,
      #           count(p.id) AS rep
      #           FROM msip_persona p
      #             LEFT JOIN msip_tdocumento t ON t.id = p.tdocumento_id
      #           GROUP BY t.sigla, p.tdocumento_id, p.numerodocumento) AS sub
      #         JOIN msip_persona AS p1 ON
      #           p1.tdocumento_id=sub.tdocumento_id
      #           AND p1.numerodocumento=sub.numerodocumento
      #         JOIN msip_persona AS p2 ON
      #           p1.id<p2.id AND
      #           p2.tdocumento_id=sub.tdocumento_id
      #           AND p2.numerodocumento=sub.numerodocumento
      #       );
      #       CREATE INDEX i_duplicado_rep_id1 ON duplicados_rep (id1);
      #       CREATE INDEX i_duplicado_rep_id2 ON duplicados_rep (id2);
      #       CREATE INDEX i_duplicado_rep_numerodocumento ON duplicados_rep (numerodocumento);
      #       CREATE INDEX i_duplicado_rep_sigla ON duplicados_rep (sigla);
      #       CREATE INDEX i_duplicado_rep_n1 ON duplicados_rep (nombres1);
      #       CREATE INDEX i_duplicado_rep_a1 ON duplicados_rep (apellidos1);
      #       CREATE INDEX i_duplicado_rep_n2 ON duplicados_rep (nombres2);
      #       CREATE INDEX i_duplicado_rep_a2 ON duplicados_rep (apellidos2);
      #       CREATE INDEX i_duplicado_rep_tn1 ON duplicados_rep (TRIM(UPPER(unaccent(nombres1))));
      #       CREATE INDEX i_duplicado_rep_ta1 ON duplicados_rep (TRIM(UPPER(unaccent(apellidos1))));
      #       CREATE INDEX i_duplicado_rep_n2 ON duplicados_rep (TRIM(UPPER(unaccent(nombres2))));
      #       CREATE INDEX i_duplicado_rep_a2 ON duplicados_rep (TRIM(UPPER(unaccent(apellidos2))));
      #       CREATE INDEX i_duplicado_rep_sn1 ON duplicados_rep (sn1);
      #       CREATE INDEX i_duplicado_rep_sa1 ON duplicados_rep (sa1);
      #       CREATE INDEX i_duplicado_rep_sn2 ON duplicados_rep (sn2);
      #       CREATE INDEX i_duplicado_rep_sa2 ON duplicados_rep (sa2);
      #    SQL
      depura = ''
      if ENV.fetch('DEPURA_MIN', -1).to_i > 0
        depura << " AND p1.id>#{ENV.fetch('DEPURA_MIN', -1).to_i}"
        depura << " AND p2.id>#{ENV.fetch('DEPURA_MIN', -1).to_i}"
      end
      if ENV.fetch('DEPURA_MAX', -1).to_i > 0
        depura << " AND p1.id<#{ENV.fetch('DEPURA_MAX', -1).to_i}"
        depura << " AND p2.id<#{ENV.fetch('DEPURA_MAX', -1).to_i}"
      end

      return Msip::Persona.connection.execute <<-SQL

      SELECT p1.tdocumento_id, p1.numerodocumento, 
        p1.id AS id1, p1.nombres AS nombres1, soundexespm(p1.nombres) AS sn1,
        p1.apellidos AS apellidos1, soundexespm(p1.apellidos) AS sa1,
        p2.id AS id2, p2.nombres AS nombres2, soundexespm(p2.nombres) AS sn2,
        p2.apellidos AS apellidos2, soundexespm(p2.apellidos) AS sa2
      FROM msip_persona AS p1
      JOIN msip_persona AS p2 
      ON p1.id<p2.id
        #{depura}
        AND p1.tdocumento_id=p2.tdocumento_id
        AND p1.numerodocumento=p2.numerodocumento
      WHERE
        (soundexespm(p1.nombres) = soundexespm(p2.nombres)
          AND soundexespm(p1.apellidos) = soundexespm(p2.apellidos)
        )  --con indices explain da 662.181
      --  OR 
      --  (((LENGTH(p2.nombres)>0 AND
      --      f_unaccent(p1.nombres) LIKE f_unaccent(p2.nombres) || '%')
      --    OR (LENGTH(p1.nombres)>0 AND
      --      f_unaccent(p2.nombres) LIKE f_unaccent(p1.nombres) || '%')
      --    )
      --   AND ((LENGTH(p2.apellidos)>0 AND
      --      f_unaccent(p1.apellidos) LIKE f_unaccent(p2.apellidos) || '%')
      --    OR (LENGTH(p1.apellidos)>0 AND
      --      f_unaccent(p2.apellidos) LIKE f_unaccent(p1.apellidos) || '%')
      --   )
      -- ) --no susceptible de indices con explain da 5'574.709.919
      --  OR 
      --  (levenshtein(p1.nombres || ' ' ||
      --      p1.apellidos,
      --      p2.nombres || ' ' ||
      --      p2.apellidos) <= 3
      --  ) --no encontramos como indexar con explain da 4'612.693.352
    ;
      SQL
      # Las 3 opciones sin igualdad entre tdocumento y numerodocumento da
      # 23'700.306.841 (mucho más que la suma de las opciones)
    end
    module_function :consulta_duplicados_autom

    # después de ejecutar este refrescar vista materializada
    # sivel2_gen_conscaso
    def deduplicar_automaticamente(current_usuario)
      puts "OJO deduplicar_automaticamente"
      puts Benchmark.measure { "a"*1_000_000_000 }
      pares = UnificarHelper.consulta_duplicados_autom
      puts "OJO consulta efectuada pares.count=#{pares.count}"
      puts Benchmark.measure { "a"*1_000_000_000 }
      res = {
        titulo: 'Beneficiarios en los que se intenta deduplicación automatica',
        encabezado: [
          'T. Doc', 'Num. doc', 'Id1', 'Nombres', 'Apellidos',
          'Id2', 'Nombres', 'Apellidos', 'Resultado'
        ],
        cuerpo: []
      }
      pares.each do |f|
        mens, idunif = unificar_dos_beneficiarios(f['id1'], f['id2'], current_usuario)
        if (mens == "")
          mens = "Unificados en <a target=_blank href='\/personas/#{idunif}'>#{idunif}</a>".html_safe
        end
        res[:cuerpo] << [
          ['sigla', f['sigla']], 
          ['numerodocumento', f['numerodocumento']],
          ['Id. 1', f['id1']], 
          ['Nombres 1', f['nombres1']], 
          ['Apellidos 1', f['apellidos1']], 
          ['Id. 2', f['id2']], 
          ['Nombres 2', f['nombres2']],
          ['Apellidos 2', f['apellidos2']], 
          ['Restultado', mens]
        ]
      end
      return res
    end
    module_function :deduplicar_automaticamente

  end
end
