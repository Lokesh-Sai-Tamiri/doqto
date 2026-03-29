import type { Metadata } from "next";
import Navbar from "@/components/layout/Navbar";
import Footer from "@/components/layout/Footer";

export const metadata: Metadata = {
  title: "HIPAA Compliance | Dox2Dox",
  description:
    "Learn how Dox2Dox maintains HIPAA compliance through administrative, physical, and technical safeguards, E2E encryption, and rigorous security practices.",
};

export default function HIPAAPage() {
  return (
    <>
      <Navbar />
      <main className="bg-dark min-h-screen pt-24 pb-16">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl sm:text-5xl font-bold text-white mb-4">
            HIPAA Compliance
          </h1>
          <p className="text-gray-500 mb-12">Last updated: March 2026</p>

          {/* 1 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">1.</span>Our Commitment to
              HIPAA
            </h2>
            <p className="text-gray-400 leading-relaxed">
              At Dox2Dox, HIPAA compliance is not an afterthought — it is
              foundational to everything we build. As a Business Associate under
              HIPAA, we are committed to protecting the privacy and security of
              Protected Health Information (PHI) entrusted to us by healthcare
              organizations and professionals. Our platform is designed from the
              ground up with the HIPAA Privacy Rule, Security Rule, and Breach
              Notification Rule in mind, ensuring that every feature, process,
              and infrastructure component meets or exceeds regulatory
              requirements.
            </p>
          </section>

          {/* 2 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">2.</span>Administrative
              Safeguards
            </h2>
            <p className="text-gray-400 leading-relaxed mb-4">
              We maintain comprehensive administrative safeguards including:
            </p>
            <ul className="list-disc list-inside text-gray-400 space-y-3 ml-4">
              <li>
                <span className="text-white">Security Officer:</span> A
                designated Security Officer responsible for the development and
                implementation of our security policies and procedures
              </li>
              <li>
                <span className="text-white">Privacy Officer:</span> A
                designated Privacy Officer responsible for the development and
                implementation of our privacy policies and procedures
              </li>
              <li>
                <span className="text-white">Workforce Training:</span> All
                employees and contractors undergo comprehensive HIPAA training
                upon hiring and annually thereafter, with additional training
                for any significant policy changes
              </li>
              <li>
                <span className="text-white">Access Management:</span>{" "}
                Role-based access controls ensure that workforce members only
                have access to the minimum PHI necessary to perform their job
                functions
              </li>
              <li>
                <span className="text-white">Sanction Policy:</span> Clear
                policies and procedures for addressing workforce members who
                violate security or privacy policies
              </li>
              <li>
                <span className="text-white">Risk Analysis:</span> Regular and
                comprehensive risk analyses to identify potential threats and
                vulnerabilities to ePHI
              </li>
            </ul>
          </section>

          {/* 3 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">3.</span>Physical Safeguards
            </h2>
            <ul className="list-disc list-inside text-gray-400 space-y-3 ml-4">
              <li>
                <span className="text-white">Facility Access Controls:</span>{" "}
                Our infrastructure is hosted in SOC 2 Type II certified data
                centers with 24/7 physical security, biometric access controls,
                and video surveillance
              </li>
              <li>
                <span className="text-white">Workstation Security:</span> All
                employee workstations are encrypted, require strong
                authentication, and are configured with automatic screen locks
                and remote wipe capabilities
              </li>
              <li>
                <span className="text-white">Device Controls:</span> Strict
                policies govern the use of removable media and mobile devices.
                All company devices are managed through a Mobile Device
                Management (MDM) solution
              </li>
              <li>
                <span className="text-white">Media Disposal:</span> Electronic
                media containing ePHI is securely wiped or physically destroyed
                before disposal or re-use, following NIST SP 800-88 guidelines
              </li>
            </ul>
          </section>

          {/* 4 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">4.</span>Technical Safeguards
            </h2>
            <ul className="list-disc list-inside text-gray-400 space-y-3 ml-4">
              <li>
                <span className="text-white">End-to-End Encryption:</span>{" "}
                AES-256 encryption ensures that only the sender and intended
                recipients can read message content
              </li>
              <li>
                <span className="text-white">Access Controls:</span> Unique
                user identification, automatic logoff, role-based permissions,
                and multi-factor authentication
              </li>
              <li>
                <span className="text-white">Audit Controls:</span>{" "}
                Comprehensive logging of all system activity, including user
                authentication, data access, and administrative actions
              </li>
              <li>
                <span className="text-white">Integrity Controls:</span>{" "}
                Mechanisms to verify that ePHI has not been improperly altered
                or destroyed, including checksums and digital signatures
              </li>
              <li>
                <span className="text-white">Transmission Security:</span> TLS
                1.3 for all data in transit, with certificate pinning for mobile
                applications
              </li>
              <li>
                <span className="text-white">Encryption at Rest:</span> All
                stored data is encrypted using AES-256 with regularly rotated
                keys
              </li>
            </ul>
          </section>

          {/* 5 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">5.</span>End-to-End Encryption
              Details
            </h2>
            <p className="text-gray-400 leading-relaxed mb-4">
              Our end-to-end encryption implementation ensures the highest level
              of data protection:
            </p>
            <ul className="list-disc list-inside text-gray-400 space-y-3 ml-4">
              <li>
                <span className="text-white">Algorithm:</span> AES-256-GCM for
                symmetric encryption of message content and file transfers
              </li>
              <li>
                <span className="text-white">Key Exchange:</span> Secure key
                exchange using modern asymmetric cryptography protocols
              </li>
              <li>
                <span className="text-white">Key Management:</span> Encryption
                keys are generated on-device and never leave the user&apos;s
                device. Keys are stored in the device&apos;s secure enclave or
                keystore
              </li>
              <li>
                <span className="text-white">Perfect Forward Secrecy:</span>{" "}
                Session keys are regularly rotated so that compromise of a
                single key does not affect past or future communications
              </li>
              <li>
                <span className="text-white">Zero-Knowledge Architecture:</span>{" "}
                Dox2Dox servers never have access to encryption keys or
                plaintext message content. Even in the event of a server
                compromise, data remains encrypted and unreadable
              </li>
            </ul>
          </section>

          {/* 6 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">6.</span>AI Clinical Assistant
              & PHI
            </h2>
            <p className="text-gray-400 leading-relaxed mb-4">
              Our AI clinical assistant, Inara, is designed with privacy by
              default:
            </p>
            <ul className="list-disc list-inside text-gray-400 space-y-3 ml-4">
              <li>
                <span className="text-white">No PHI Storage:</span> Inara does
                not store patient-identifiable information. Queries are
                processed in real-time and discarded after generating a response
              </li>
              <li>
                <span className="text-white">No Model Training on PHI:</span>{" "}
                Patient data is never used to train, fine-tune, or improve AI
                models
              </li>
              <li>
                <span className="text-white">Isolated Processing:</span> AI
                processing occurs within our HIPAA-compliant infrastructure with
                strict network segmentation
              </li>
              <li>
                <span className="text-white">Audit Trail:</span> All AI
                interactions are logged for compliance auditing purposes
                (metadata only, not content)
              </li>
              <li>
                <span className="text-white">User Control:</span> Healthcare
                professionals maintain full control over what information, if
                any, they share with Inara
              </li>
            </ul>
          </section>

          {/* 7 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">7.</span>Breach Notification
              Procedures
            </h2>
            <p className="text-gray-400 leading-relaxed mb-4">
              In the event of a breach of unsecured PHI, Dox2Dox will:
            </p>
            <ul className="list-decimal list-inside text-gray-400 space-y-3 ml-4">
              <li>
                Investigate and contain the breach immediately upon discovery
              </li>
              <li>
                Notify affected Covered Entities without unreasonable delay and
                no later than sixty (60) days after discovery
              </li>
              <li>
                Provide all information required under 45 CFR § 164.410,
                including the nature of the breach, types of PHI involved, and
                steps taken to mitigate harm
              </li>
              <li>
                Cooperate with Covered Entities in their notification
                obligations to affected individuals and the HHS Secretary
              </li>
              <li>
                Conduct a thorough post-incident review and implement
                corrective actions to prevent recurrence
              </li>
              <li>
                Document all aspects of the breach, investigation, and response
                for a minimum of six (6) years
              </li>
            </ul>
          </section>

          {/* 8 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">8.</span>Business Associate
              Agreements
            </h2>
            <p className="text-gray-400 leading-relaxed">
              Dox2Dox enters into Business Associate Agreements (BAAs) with all
              Covered Entities that use our platform. We also maintain BAAs with
              our own subcontractors and service providers who may have access to
              PHI. Our BAA outlines the permitted uses and disclosures of PHI,
              our security obligations, breach notification procedures, and
              termination provisions. You can review our standard BAA on the{" "}
              <a href="/baa" className="text-primary hover:underline">
                BAA page
              </a>
              .
            </p>
          </section>

          {/* 9 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">9.</span>Employee Training &
              Awareness
            </h2>
            <ul className="list-disc list-inside text-gray-400 space-y-3 ml-4">
              <li>
                All employees complete comprehensive HIPAA training within 30
                days of hiring
              </li>
              <li>
                Annual refresher training is mandatory for all team members
              </li>
              <li>
                Role-specific training is provided for employees with access to
                PHI or critical systems
              </li>
              <li>
                Regular phishing simulations and security awareness campaigns
              </li>
              <li>
                Documented training records maintained for a minimum of six (6)
                years
              </li>
            </ul>
          </section>

          {/* 10 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">10.</span>Regular Audits &
              Risk Assessments
            </h2>
            <ul className="list-disc list-inside text-gray-400 space-y-3 ml-4">
              <li>
                Annual comprehensive risk assessments in accordance with NIST
                Cybersecurity Framework
              </li>
              <li>
                Regular internal security audits and code reviews
              </li>
              <li>
                Annual third-party penetration testing by qualified security
                firms
              </li>
              <li>
                Continuous vulnerability scanning and patch management
              </li>
              <li>
                Periodic review and update of all security policies and
                procedures
              </li>
              <li>
                SOC 2 Type II certification maintained and audited annually
              </li>
            </ul>
          </section>

          {/* 11 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">11.</span>Data Backup &
              Disaster Recovery
            </h2>
            <ul className="list-disc list-inside text-gray-400 space-y-3 ml-4">
              <li>
                Automated, encrypted backups performed daily with geographically
                distributed storage
              </li>
              <li>
                Recovery Point Objective (RPO) of less than 24 hours and
                Recovery Time Objective (RTO) of less than 4 hours
              </li>
              <li>
                Disaster recovery plan tested and validated at least twice
                annually
              </li>
              <li>
                Multi-region infrastructure with automatic failover capabilities
              </li>
              <li>
                Business continuity plan reviewed and updated annually
              </li>
            </ul>
          </section>

          {/* 12 */}
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-white mb-4">
              <span className="text-primary mr-2">12.</span>Contact Information
            </h2>
            <p className="text-gray-400 leading-relaxed">
              For questions about our HIPAA compliance practices or to report a
              potential security concern:
            </p>
            <div className="mt-4 text-gray-400">
              <p className="text-white font-medium">
                Dox2Dox, Inc. — Compliance Officer
              </p>
              <p>
                Email:{" "}
                <a
                  href="mailto:compliance@dox2dox.com"
                  className="text-primary hover:underline"
                >
                  compliance@dox2dox.com
                </a>
              </p>
              <p>
                Security:{" "}
                <a
                  href="mailto:security@dox2dox.com"
                  className="text-primary hover:underline"
                >
                  security@dox2dox.com
                </a>
              </p>
              <p>
                General:{" "}
                <a
                  href="mailto:hello@hymnchat.com"
                  className="text-primary hover:underline"
                >
                  hello@hymnchat.com
                </a>
              </p>
            </div>
          </section>
        </div>
      </main>
      <Footer />
    </>
  );
}
